-- Integração real: Rename/Move via JDTLS, com preview, cancelamento,
-- bloqueio de buffer modificado no destino e apply de RenameFile.
--
-- Run:
--   nvim --headless -u NONE \
--     -c "set rtp+=~/.config/nvim" \
--     -c "set rtp+=~/.local/share/nvim/lazy/nvim-jdtls" \
--     -c "set rtp+=~/.local/share/nvim/lazy/nvim-lspconfig" \
--     -c "set rtp+=~/.local/share/nvim/lazy/jc.nvim" \
--     -c "luafile tests/java_menu/refactor_lsp_spec.lua" -c qa

local lsp = require("java_menu.lsp")
local fixtures = require("tests.java_menu.fixtures")
local ui = require("java_menu.ui")
local refactor = require("java_menu.refactor")

local ok_jdtls, jdtls = pcall(require, "jdtls")
assert(ok_jdtls and type(jdtls.start_or_attach) == "function", "nvim-jdtls indisponível")

local jdtls_bin = vim.fn.exepath("jdtls")
if jdtls_bin == "" then
  jdtls_bin = vim.fn.stdpath("data") .. "/mason/bin/jdtls"
end
assert(vim.fn.filereadable(jdtls_bin) == 1, "jdtls não está disponível")

local root, widget_file = fixtures.maven_project("refactor-reg", "com.demo.ref", "Widget")
local extra_file = root .. "/src/main/java/com/demo/ref/Extra.java"
vim.fn.writefile(
  vim.split(
    [[
package com.demo.ref;

public class Extra {
}
]],
    "\n",
    { plain = true }
  ),
  extra_file
)

local function read(path)
  return table.concat(vim.fn.readfile(path), "\n")
end

local function open(path)
  path = vim.fs.normalize(path)
  local buf = vim.fn.bufnr(path)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    if vim.api.nvim_get_current_buf() ~= buf then
      vim.api.nvim_set_current_buf(buf)
    end
  else
    vim.cmd("edit " .. vim.fn.fnameescape(path))
  end
  if path:sub(-5) == ".java" and vim.bo.filetype ~= "java" then
    vim.bo.filetype = "java"
  end
end

open(widget_file)
jdtls.start_or_attach({
  cmd = { jdtls_bin, "-data", root .. "-data" },
  root_dir = root,
})
local attached = fixtures.wait_for(45000, function()
  return lsp.client(0) ~= nil
end)
assert(attached, "JDTLS não anexou")

-- stubs de UI, por operação
local menu_choice
local ask_value
local preview_choice
local destination_pattern
local notices = {}
local preview_opened = false

ui.notify = function(msg, _)
  notices[#notices + 1] = tostring(msg)
end
ui.ask = function(_, _, cb)
  cb(ask_value)
end
ui.pick_one = function(items, prompt, cb)
  if prompt == "Java: Refactor" then
    for _, item in ipairs(items) do
      if item:sub(1, #menu_choice) == menu_choice then
        cb(item)
        return
      end
    end
  elseif prompt:find("mover", 1, true) then
    for _, item in ipairs(items) do
      if
        item:find(destination_pattern, 1, true)
        and not item:find("indisponível", 1, true)
        and not item:find("já é o package atual", 1, true)
      then
        cb(item)
        return
      end
    end
  elseif prompt == "Java: Preview — alterações" then
    preview_opened = true
    for _, item in ipairs(items) do
      if item:find(preview_choice, 1, true) then
        cb(item)
        return
      end
    end
  end
  cb(nil)
end

local function has_notice(text)
  for _, notice in ipairs(notices) do
    if notice:find(text, 1, true) then
      return true
    end
  end
  return false
end

local function cursor_on_class(path, class_name)
  open(path)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i, line in ipairs(lines) do
    local col = line:find(class_name, 1, true)
    if col and line:find("class%s+" .. class_name) then
      vim.api.nvim_win_set_cursor(0, { i, col - 1 })
      return
    end
  end
  error("classe não encontrada em " .. path)
end

-- 1. Rename bloqueado por buffer modificado no destino
local blocked_target = root .. "/src/main/java/com/demo/ref/Unsaved.java"
local stale = vim.fn.bufadd(blocked_target)
vim.api.nvim_buf_set_lines(stale, 0, -1, false, { "trabalho não salvo" })
assert(vim.bo[stale].modified, "buffer stale de teste não ficou modificado")

cursor_on_class(widget_file, "Widget")
notices = {}
menu_choice = "Rename Symbol"
ask_value = "Unsaved"
preview_choice = "✔ Aplicar alterações"
preview_opened = false
refactor.refactor()
fixtures.wait_for(30000, function()
  return preview_opened and has_notice("não apliquei")
end)
assert(preview_opened, "preview do rename bloqueado não abriu")
assert(has_notice("não apliquei"), "bloqueio do buffer modificado não apareceu: " .. vim.inspect(notices))
assert(vim.fn.filereadable(blocked_target) == 0, "bloqueio criou o destino")
assert(read(widget_file):find("class Widget", 1, true) ~= nil, "bloqueio alterou a origem")
vim.bo[stale].modified = false
vim.api.nvim_buf_delete(stale, { force = true })

-- 2. Rename aplicado com RenameFile + TextDocumentEdit
cursor_on_class(widget_file, "Widget")
notices = {}
menu_choice = "Rename Symbol"
ask_value = "WidgetRenamed"
preview_choice = "✔ Aplicar alterações"
preview_opened = false
local renamed_file = root .. "/src/main/java/com/demo/ref/WidgetRenamed.java"
refactor.refactor()
fixtures.wait_for(30000, function()
  return vim.fn.filereadable(renamed_file) == 1 and vim.fn.filereadable(widget_file) == 0
end)
assert(vim.fn.filereadable(renamed_file) == 1, "rename não criou o destino")
assert(vim.fn.filereadable(widget_file) == 0, "rename não removeu a origem")
local renamed_buf = vim.fn.bufnr(renamed_file)
assert(renamed_buf ~= -1 and vim.api.nvim_buf_is_loaded(renamed_buf), "rename não manteve o buffer destino")
local buffer_text = table.concat(vim.api.nvim_buf_get_lines(renamed_buf, 0, -1, false), "\n")
assert(buffer_text:find("class WidgetRenamed", 1, true) ~= nil, "rename não atualizou a declaração")
assert(vim.bo[renamed_buf].modified, "rename deveria deixar o buffer para o usuário salvar")
local reattached = fixtures.wait_for(5000, function()
  return lsp.client(renamed_buf) ~= nil
end)
assert(reattached, "o buffer renomeado não herdou o cliente JDTLS")
vim.cmd("silent wa")
assert(read(renamed_file):find("class WidgetRenamed", 1, true) ~= nil, "rename não persistiu após :wa")

-- 3. Move Class abre destinos por source root e o cancelamento não altera nada
cursor_on_class(renamed_file, "WidgetRenamed")
notices = {}
menu_choice = "Move Class"
destination_pattern = "[src/main/java]"
preview_choice = "✖ Cancelar"
preview_opened = false
local before = read(renamed_file)
refactor.refactor()
fixtures.wait_for(30000, function()
  return preview_opened
end)
assert(preview_opened, "preview do Move Class não abriu")
assert(has_notice("refatoração cancelada"), "cancelamento do Move não avisou")
assert(read(renamed_file) == before, "cancelamento do Move alterou a origem")
assert(vim.fn.filereadable(renamed_file) == 1, "cancelamento do Move removeu a origem")

print("refactor_lsp_spec: OK")
vim.cmd("qa!")

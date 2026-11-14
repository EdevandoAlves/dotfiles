-- java_menu/ui.lua
-- Componentes de UI compartilhados pelos menus Java (snacks, sem tocar em
-- vim.ui.select/input globais).

local M = {}

function M.notify(msg, level)
  vim.notify("Java: " .. msg, level or vim.log.levels.INFO)
end

function M.snacks()
  local ok, mod = pcall(require, "snacks")
  if ok and mod.picker and type(mod.picker.pick) == "function" then
    return mod
  end
end

---Seleção central simples.
function M.pick_one(items, prompt, on_choice)
  local mod = M.snacks()
  if not mod then
    M.notify("Snacks não está disponível para a seleção", vim.log.levels.ERROR)
    return
  end
  mod.picker.select(items, { prompt = prompt }, function(choice)
    if choice ~= nil then
      on_choice(choice)
    end
  end)
end

---Entrada central de texto (Snacks), com fallback para vim.ui.input.
function M.ask(prompt, default, on_confirm)
  local mod = M.snacks()
  if mod and mod.input and type(mod.input.input) == "function" then
    return mod.input.input({ prompt = prompt, default = default or "" }, on_confirm)
  end
  return vim.ui.input({ prompt = prompt, default = default or "" }, on_confirm)
end

---Menu central com estados disponíveis/indisponíveis.
---@param entries table[] { key, label, enabled, reason }
---@param prompt string
---@param on_choice fun(entry: table)
function M.menu(entries, prompt, on_choice)
  local labels, by_label = {}, {}
  for _, entry in ipairs(entries) do
    local text = entry.label
    -- só é indisponível quando dito explicitamente (enabled == false)
    if entry.enabled == false then
      text = text .. "  (indisponível: " .. (entry.reason or "sem motivo") .. ")"
    end
    labels[#labels + 1] = text
    by_label[text] = entry
  end

  M.pick_one(labels, prompt, function(choice)
    local entry = by_label[choice]
    if not entry then
      return
    end
    if entry.enabled == false then
      M.notify(entry.reason or "operação indisponível", vim.log.levels.WARN)
      return
    end
    on_choice(entry)
  end)
end

function M.jdtls_attached(bufnr)
  return #vim.lsp.get_clients({ name = "jdtls", bufnr = bufnr }) > 0
end

---Parser treesitter da linguagem disponível?
function M.has_parser(bufnr, lang)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  return ok and parser ~= nil
end

---Unidade de indentação do arquivo (primeira linha indentada).
local function detect_indent(bufnr)
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, 200, false)) do
    local spaces = line:match("^( +)%S")
    if spaces then
      return #spaces
    end
  end
  return vim.bo[bufnr].shiftwidth > 0 and vim.bo[bufnr].shiftwidth or 4
end

---Alinha o shiftwidth à indentação real do arquivo durante `fn` e restaura
---depois (o jdtls formata o código gerado/refatorado com esse valor).
function M.with_indent(bufnr, fn)
  local sw, ts, et = vim.bo[bufnr].shiftwidth, vim.bo[bufnr].tabstop, vim.bo[bufnr].expandtab
  local unit = detect_indent(bufnr)
  vim.bo[bufnr].expandtab = true
  vim.bo[bufnr].shiftwidth = unit
  vim.bo[bufnr].tabstop = unit
  local ok, err = pcall(fn)
  vim.bo[bufnr].shiftwidth, vim.bo[bufnr].tabstop, vim.bo[bufnr].expandtab = sw, ts, et
  if not ok then
    M.notify(tostring(err), vim.log.levels.ERROR)
  end
end

---O buffer alvo ainda é o buffer atual? (evita agir no arquivo errado)
function M.same_buffer(bufnr)
  if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
    M.notify("o buffer alvo não existe mais", vim.log.levels.WARN)
    return false
  end
  if vim.api.nvim_get_current_buf() ~= bufnr then
    M.notify("o buffer mudou desde a abertura do menu — refaça a operação", vim.log.levels.WARN)
    return false
  end
  return true
end

return M

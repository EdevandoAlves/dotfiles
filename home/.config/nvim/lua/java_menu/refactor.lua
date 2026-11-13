-- java_menu/refactor.lua
-- <leader>jr: refatorações locais (single-file) sobre a API do jc.nvim.
--
-- A seleção Visual é capturada ANTES de abrir o picker (buffer, modo, intervalo
-- e changedtick) e reaplicada via marcas '< / '> no momento de executar, que é
-- o que o jc/nvim lê (vim.lsp.util.make_given_range_params). Nada é reaproveitado
-- de marcas Visual antigas e nenhuma operação roda em outro buffer.

local ui = require("java_menu.ui")

local M = {}

local BLOCK_MODE = "\22" -- <C-v>

---@class VisualCtx
---@field bufnr number
---@field mode string "v" | "V" | "<C-v>"
---@field start_line number 0-based
---@field start_col number 0-based
---@field end_line number 0-based
---@field end_col number 0-based (último caractere selecionado)
---@field tick number changedtick no momento da captura

---Captura a seleção Visual atual (antes de qualquer picker).
---@return VisualCtx|nil
local function capture_visual()
  local mode = vim.fn.mode()
  if mode ~= "v" and mode ~= "V" and mode ~= BLOCK_MODE then
    return nil
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local anchor = vim.fn.getpos("v") -- 1-based
  local cursor = vim.fn.getpos(".") -- 1-based
  local a = { anchor[2], anchor[3] }
  local b = { cursor[2], cursor[3] }

  if a[1] > b[1] or (a[1] == b[1] and a[2] > b[2]) then
    a, b = b, a
  end

  local start_line, start_col = a[1] - 1, a[2] - 1
  local end_line, end_col = b[1] - 1, b[2] - 1

  if mode == "V" then
    start_col = 0
    local line = vim.api.nvim_buf_get_lines(bufnr, end_line, end_line + 1, false)[1] or ""
    end_col = math.max(0, #line - 1)
  end

  return {
    bufnr = bufnr,
    mode = mode,
    start_line = start_line,
    start_col = start_col,
    end_line = end_line,
    end_col = end_col,
    tick = vim.b[bufnr].changedtick,
  }
end

---Sai do modo Visual sem depender de mapeamentos.
local function leave_visual()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
end

---Reaplica a seleção capturada e executa `fn`.
---@param ctx VisualCtx
---@param fn fun()
local function with_selection(ctx, fn)
  if not ui.same_buffer(ctx.bufnr) then
    return
  end
  if vim.b[ctx.bufnr].changedtick ~= ctx.tick then
    ui.notify("o buffer foi modificado desde a seleção — refaça o Extract", vim.log.levels.WARN)
    return
  end
  -- marcas do buffer, no formato que make_given_range_params consome:
  -- linha 1-based, coluna 0-based
  vim.api.nvim_buf_set_mark(ctx.bufnr, "<", ctx.start_line + 1, ctx.start_col, {})
  vim.api.nvim_buf_set_mark(ctx.bufnr, ">", ctx.end_line + 1, ctx.end_col, {})
  ui.with_indent(ctx.bufnr, fn)
end

---@param fn_name string extract_variable | extract_variable_all | extract_constant | extract_method
local function run_extract(ctx, fn_name)
  local jc = require("jc.refactor")
  if ctx then
    with_selection(ctx, function()
      jc[fn_name](true)
    end)
  else
    jc[fn_name](false)
  end
end

local RUNNERS = {
  extract_variable = function(ctx)
    run_extract(ctx, "extract_variable")
  end,
  extract_variable_all = function(ctx)
    run_extract(ctx, "extract_variable_all")
  end,
  extract_constant = function(ctx)
    run_extract(ctx, "extract_constant")
  end,
  extract_method = function(ctx)
    run_extract(ctx, "extract_method")
  end,
  static_import = function()
    require("jc.jdtls").convert_static_import(true)
  end,
  static_import_enum = function()
    require("jc.jdtls").static_import_enum()
  end,
  flip_args = function()
    require("jc.refactor").flip_call_args()
  end,
}

---@param ctx VisualCtx|nil
---@param bufnr number
local function entries(ctx, bufnr)
  local attached = ui.jdtls_attached(bufnr)
  local parser = ui.has_parser(bufnr, "java")
  local no_jdtls = "jdtls não está anexado a este buffer"

  local has_selection = ctx ~= nil and (ctx.start_line ~= ctx.end_line or ctx.start_col ~= ctx.end_col)
  local block = ctx ~= nil and ctx.mode == BLOCK_MODE

  local method_reason
  if not attached then
    method_reason = no_jdtls
  elseif block then
    method_reason = "seleção por blocos (<C-v>) não é suportada"
  elseif not has_selection then
    method_reason = "selecione o trecho no modo Visual antes de <leader>jr"
  end

  return {
    { key = "extract_variable", label = "Extract Variable", enabled = attached, reason = no_jdtls },
    {
      key = "extract_variable_all",
      label = "Extract Variable (all occurrences)",
      enabled = attached,
      reason = no_jdtls,
    },
    { key = "extract_constant", label = "Extract Constant", enabled = attached, reason = no_jdtls },
    {
      key = "extract_method",
      label = "Extract Method",
      enabled = attached and has_selection and not block,
      reason = method_reason,
    },
    { key = "static_import", label = "Static Import", enabled = attached, reason = no_jdtls },
    {
      key = "static_import_enum",
      label = "Static Import Enum",
      enabled = attached and parser,
      reason = (not attached and no_jdtls) or "parser treesitter de Java não instalado",
    },
    {
      key = "flip_args",
      label = "Flip Arguments",
      enabled = parser,
      reason = "parser treesitter de Java não instalado",
    },
  }
end

---Entrada do `<leader>jr` (normal ou visual).
function M.refactor()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "java" then
    ui.notify("Refactor exige um buffer Java", vim.log.levels.WARN)
    return
  end

  -- captura antes de abrir o picker
  local ctx = capture_visual()
  if ctx then
    leave_visual()
  end

  ui.menu(entries(ctx, bufnr), "Java: Refactor", function(entry)
    local runner = RUNNERS[entry.key]
    if runner then
      runner(ctx)
    end
  end)
end

-- expostos para testes
M._capture_visual = capture_visual
M._entries = entries

return M

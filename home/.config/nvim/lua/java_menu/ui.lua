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

---Seleção central simples. Sem Snacks, mantém a operação funcional pelo
---vim.ui.select (sem substituir a função global).
function M.pick_one(items, prompt, on_choice)
  local mod = M.snacks()
  if not mod then
    vim.ui.select(items, { prompt = prompt }, function(choice)
      if choice ~= nil then
        on_choice(choice)
      end
    end)
    return
  end
  mod.picker.select(items, { prompt = prompt }, function(choice)
    if choice ~= nil then
      on_choice(choice)
    end
  end)
end

---Seleção múltipla (Snacks): Space/Tab alterna, Enter confirma.
---Nada selecionado devolve {} (etapa opcional pode ser pulada).
---Itens podem ser strings ou `{ text = "…", value = … }`; o callback recebe os
---valores (ou o próprio texto).
---@param items (string|{text:string, value:any})[]
---@param prompt string
---@param on_confirm fun(selected:any[])
---@param opts { fallback: boolean|nil, help: boolean|nil }|nil
--- fallback = Enter sem seleção usa o item sob o cursor
--- help = mostra a linha curta de teclas no título (padrão: true)
function M.pick_many(items, prompt, on_confirm, opts)
  opts = opts or {}

  local entries = {}
  local by_text = {}
  for i, item in ipairs(items) do
    local text = type(item) == "table" and item.text or tostring(item)
    local value = type(item) == "table" and item.value or item
    by_text[text] = value
    entries[#entries + 1] = { text = text, item = { text = text, value = value, idx = i } }
  end

  local mod = M.snacks()
  if not mod or type(mod.picker.pick) ~= "function" then
    -- fallback sem Snacks: lista separada por vírgula
    vim.ui.input({ prompt = prompt .. " (separados por vírgula; vazio = nenhum): " }, function(value)
      if value == nil then
        return
      end
      local out = {}
      for part in value:gmatch("[^,]+") do
        local text = vim.trim(part)
        if text ~= "" then
          out[#out + 1] = by_text[text] or text
        end
      end
      on_confirm(out)
    end)
    return
  end

  local title = prompt
  if opts.help ~= false then
    title = prompt .. "  ·  Space/Tab · Enter · Esc"
  end

  mod.picker.pick({
    title = title,
    source = "java_menu_multi",
    -- mesma moldura dos seletores simples, sem preview de dados internos
    layout = { preset = "select", preview = false },
    finder = function()
      return vim.deepcopy(entries)
    end,
    -- "text" devolve chunks de highlight; uma string quebraria o render
    format = "text",
    win = {
      input = {
        keys = {
          -- Tab marca sem tirar o foco da busca; Space fica livre para a busca
          ["<Tab>"] = { "select_and_next", mode = { "n", "i" } },
        },
      },
      list = {
        keys = {
          ["<Space>"] = "select_and_next",
          ["<Tab>"] = "select_and_next",
        },
      },
    },
    confirm = function(picker)
      local selected = picker:selected({ fallback = opts.fallback == true })
      picker:close()
      table.sort(selected, function(a, b)
        return (a.item and a.item.idx or 0) < (b.item and b.item.idx or 0)
      end)
      local out = {}
      for _, entry in ipairs(selected) do
        if entry.item and entry.item.value ~= nil then
          out[#out + 1] = entry.item.value
        end
      end
      vim.schedule(function()
        on_confirm(out)
      end)
    end,
  })
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

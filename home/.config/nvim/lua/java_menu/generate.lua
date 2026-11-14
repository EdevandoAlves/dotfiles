-- java_menu/generate.lua
-- <leader>jg: menu Generate com seleção múltipla central (Snacks).
-- A geração do código Java continua sendo do jc.nvim/jdtls
-- (require("jc.jdtls").generate_*); este módulo só coleta os candidatos,
-- apresenta a seleção e checa duplicados.
--
-- Nota: o seletor de campos do jc.nvim é um split de scratch buffer onde se
-- apagam linhas. Substituímos apenas essa UI por Snacks e reaproveitamos as
-- funções públicas do jc, que aceitam a lista de campos já escolhida.

local ui = require("java_menu.ui")

local M = {}

local notify = ui.notify

-- ---------- infraestrutura ----------

local function jdtls_attached(bufnr)
  return ui.jdtls_attached(bufnr)
end

---Executa `fn` com o buffer alvo como corrente (as funções do jc usam o
---buffer 0) e devolve o foco para onde o usuário estava. Se `tick` for dado,
---recusa a operação quando o buffer mudou desde o início do menu.
local function in_buffer(bufnr, fn, tick)
  if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
    return
  end
  if tick and vim.b[bufnr].changedtick ~= tick then
    notify("o buffer mudou durante a operação — refaça o Generate", vim.log.levels.WARN)
    return
  end

  local prev_win = vim.api.nvim_get_current_win()
  local prev_buf = vim.api.nvim_get_current_buf()
  local switched = prev_buf ~= bufnr

  if switched then
    local win = vim.fn.bufwinid(bufnr)
    if win ~= -1 then
      pcall(vim.api.nvim_set_current_win, win)
    else
      pcall(vim.api.nvim_set_current_buf, bufnr)
    end
  end

  local ok, err = pcall(fn)

  if switched and vim.api.nvim_buf_is_valid(prev_buf) then
    if vim.api.nvim_win_is_valid(prev_win) then
      pcall(vim.api.nvim_set_current_win, prev_win)
    end
    if vim.api.nvim_get_current_buf() ~= prev_buf then
      pcall(vim.api.nvim_set_current_buf, prev_buf)
    end
  end

  if not ok then
    notify(tostring(err), vim.log.levels.ERROR)
  end
end

local with_indent = ui.with_indent

local function range_params()
  local client = require("jc.lsp").get_jdtls_client()
  local encoding = client and client.offset_encoding or "utf-16"
  return vim.lsp.util.make_range_params(0, encoding)
end

-- ---------- dados da classe (jdtls) ----------

local CLASS_KINDS = { [5] = true, [10] = true, [11] = true, [23] = true } -- Class, Enum, Interface, Struct
local FIELD, METHOD, CONSTRUCTOR = 8, 6, 9

local function class_node(symbols)
  for _, node in ipairs(symbols or {}) do
    if CLASS_KINDS[node.kind] then
      return node
    end
  end
end

---`getNome()` -> `getNome`
local function base_name(name)
  return (name:gsub("%s*%b()$", ""))
end

local function has_method(methods, name)
  for _, method in ipairs(methods or {}) do
    if base_name(method.name) == name then
      return true
    end
  end
  return false
end

---A classe declara um construtor sem parâmetros?
local function has_default_constructor(node, ctors)
  local class = node and node.name or ""
  for _, ctor in ipairs(ctors or {}) do
    if (ctor.name or "") == class .. "()" then
      return true
    end
  end
  return false
end

---Erasa genéricos: Map<String, List<Long>> -> Map
local function erase_generics(t)
  local prev
  repeat
    prev = t
    t = t:gsub("<[^<>]*>", "")
  until t == prev
  return (t:gsub("%s+", ""))
end

---Construtor com os mesmos tipos (na ordem) já existe?
local function constructor_exists(node, ctors, fields)
  local types = {}
  for _, field in ipairs(fields) do
    types[#types + 1] = erase_generics(field.type or "?")
  end
  local want = erase_generics((node and node.name or "") .. "(" .. table.concat(types, ", ") .. ")")
  for _, ctor in ipairs(ctors or {}) do
    if erase_generics(ctor.name or "") == want then
      return true
    end
  end
  return false
end

---"pending" (há método abstrato a implementar), "none" (diagnósticos
---publicados e nada pendente) ou "unknown" (jdtls ainda não publicou nada).
local function abstract_state(bufnr)
  local diagnostics = vim.diagnostic.get(bufnr)
  if #diagnostics == 0 then
    return "unknown"
  end
  for _, diag in ipairs(diagnostics) do
    if
      tostring(diag.code) == "67109264"
      or (
        diag.message and (diag.message:find("must implement", 1, true) or diag.message:find("must override", 1, true))
      )
    then
      return "pending"
    end
  end
  return "none"
end

---Coleta símbolos, acessores pendentes e status de construtores.
---@param bufnr number
---@param cb fun(state: table)
local function load_state(bufnr, cb)
  local state = {
    bufnr = bufnr,
    tick = vim.b[bufnr].changedtick,
    fields = {},
    methods = {},
    ctors = {},
    accessors = {},
    ctor_fields = {},
    constructors = {},
  }
  if not jdtls_attached(bufnr) then
    cb(state)
    return
  end

  local pending = 3
  local function done()
    pending = pending - 1
    if pending == 0 then
      cb(state)
    end
  end

  local lsp = require("jc.lsp")

  lsp.jdtls_request(
    bufnr,
    "textDocument/documentSymbol",
    { textDocument = vim.lsp.util.make_text_document_params(bufnr) },
    function(err, resp)
      if resp then
        state.node = class_node(resp)
        for _, child in ipairs(state.node and state.node.children or {}) do
          if child.kind == METHOD then
            state.methods[#state.methods + 1] = child
          elseif child.kind == CONSTRUCTOR then
            state.ctors[#state.ctors + 1] = child
          elseif child.kind == FIELD then
            state.fields[#state.fields + 1] = { name = child.name }
          end
        end
      else
        state.error = err
      end
      done()
    end
  )

  in_buffer(bufnr, function()
    local params = range_params()
    params.kind = 2
    lsp.jdtls_request(bufnr, "java/resolveUnimplementedAccessors", params, function(err, resp)
      if resp then
        vim.list_extend(state.accessors, resp)
      else
        state.error = state.error or err
      end
      done()
    end)

    lsp.jdtls_request(bufnr, "java/checkConstructorsStatus", range_params(), function(err, resp)
      if resp then
        state.ctor_fields = resp.fields or {}
        state.constructors = resp.constructors or {}
      else
        state.error = state.error or err
      end
      done()
    end)
  end)
end

-- ---------- seleção (Snacks) ----------

---Seleção central com múltipla escolha (Space/Tab alternam; Enter sem seleção
---usa o item sob o cursor). Delegate para o componente compartilhado.
---@param items table[] { text, data, idx }
---@param opts { title: string, allow_empty: boolean|nil }
---@param on_confirm fun(selected: table[])
local function pick_multi(items, opts, on_confirm)
  local entries = {}
  for _, item in ipairs(items) do
    entries[#entries + 1] = { text = item.text, value = item }
  end
  ui.pick_many(entries, opts.title, on_confirm, { fallback = true })
end

local pick_one = ui.pick_one

local function confirm_replace(what, on_yes)
  pick_one({ "Substituir " .. what, "Cancelar" }, "Java: Generate — " .. what .. " já existe", function(choice)
    if choice == "Substituir " .. what then
      on_yes()
    end
  end)
end

-- ---------- operações ----------

local function field_items(fields, suffix)
  local items = {}
  for i, field in ipairs(fields) do
    local text = (field.type or "?") .. " " .. field.name
    if suffix then
      text = text .. suffix(field)
    end
    items[#items + 1] = { text = text, data = field, idx = i }
  end
  return items
end

local function constructor(state, default)
  local bufnr = state.bufnr
  if default then
    in_buffer(bufnr, function()
      with_indent(bufnr, function()
        require("jc.jdtls").generate_constructor({}, { default_constructor = true, constructors = state.constructors })
      end)
    end, state.tick)
    return
  end

  local fields = state.ctor_fields
  if #fields == 0 then
    notify("a classe não tem atributos para o construtor", vim.log.levels.WARN)
    return
  end

  pick_multi(field_items(fields), { title = "Java: Generate — Constructor (selecione os campos)" }, function(selected)
    if #selected == 0 then
      return
    end
    local chosen = {}
    for _, item in ipairs(selected) do
      chosen[#chosen + 1] = item.data
    end
    if constructor_exists(state.node, state.ctors, chosen) then
      notify("já existe um construtor com esses parâmetros", vim.log.levels.WARN)
      return
    end
    in_buffer(bufnr, function()
      with_indent(bufnr, function()
        require("jc.jdtls").generate_constructor(chosen, {
          default_constructor = false,
          constructors = state.constructors,
        })
      end)
    end, state.tick)
  end)
end

---@param mode string "get"|"set"|"both"
local function accessors(state, mode)
  local bufnr = state.bufnr
  local items = {}

  for i, entry in ipairs(state.accessors or {}) do
    local can_get = entry.generateGetter
    local can_set = entry.generateSetter
    local text = (entry.typeName or "?") .. " " .. entry.fieldName
    if entry.isStatic then
      text = text .. "  (static)"
    end

    local available = (mode == "get" and can_get)
      or (mode == "set" and can_set)
      or (mode == "both" and (can_get or can_set))
    if available then
      items[#items + 1] = {
        text = text,
        idx = i,
        data = {
          fieldName = entry.fieldName,
          generateGetter = mode ~= "set" and can_get,
          generateSetter = mode ~= "get" and can_set,
        },
      }
    elseif mode == "set" and not can_set then
      items[#items + 1] =
        { text = text .. "  (indisponível: campo final ou setter existente)", idx = i, disabled = true }
    elseif mode == "get" and not can_get then
      items[#items + 1] = { text = text .. "  (indisponível: getter existente)", idx = i, disabled = true }
    end
  end

  local available = vim.tbl_filter(function(item)
    return not item.disabled
  end, items)

  if #available == 0 then
    notify("nenhum campo disponível para " .. (mode == "both" and "getter/setter" or mode), vim.log.levels.WARN)
    return
  end

  local title = "Java: Generate — "
    .. (mode == "both" and "Getter + Setter" or (mode == "get" and "Getter" or "Setter"))

  pick_multi(items, { title = title .. " (selecione os campos)" }, function(selected)
    local chosen = {}
    for _, item in ipairs(selected) do
      if item.disabled then
        notify("campo sem acessor disponível na seleção", vim.log.levels.WARN)
      else
        chosen[#chosen + 1] = item.data
      end
    end
    if #chosen == 0 then
      return
    end
    in_buffer(bufnr, function()
      with_indent(bufnr, function()
        require("jc.jdtls").generate_accessors(chosen)
      end)
    end, state.tick)
  end)
end

local TOSTRING_STYLES = {
  "STRING_CONCATENATION",
  "STRING_BUILDER",
  "STRING_BUILDER_CHAINED",
  "STRING_FORMAT",
}

local function tostring_op(state)
  local bufnr = state.bufnr
  in_buffer(bufnr, function()
    require("jc.lsp").jdtls_request(bufnr, "java/checkToStringStatus", range_params(), function(err, resp)
      if not resp then
        notify("checkToStringStatus falhou: " .. vim.inspect(err), vim.log.levels.WARN)
        return
      end

      local fields = vim.tbl_filter(function(field)
        return field.isField
      end, resp.fields or {})

      if #fields == 0 then
        notify("a classe não tem atributos para o toString()", vim.log.levels.WARN)
        return
      end

      pick_multi(
        field_items(fields),
        { title = "Java: Generate — toString() (selecione os campos)" },
        function(selected)
          if #selected == 0 then
            return
          end
          local chosen = {}
          for _, item in ipairs(selected) do
            chosen[#chosen + 1] = item.data
          end
          pick_one(TOSTRING_STYLES, "Java: Generate — estilo do toString()", function(style)
            in_buffer(bufnr, function()
              with_indent(bufnr, function()
                require("jc.jdtls").generate_toString(chosen, { code_style = style })
              end)
            end, state.tick)
          end)
        end
      )
    end)
  end)
end

local function equals_hashcode(state)
  local bufnr = state.bufnr
  in_buffer(bufnr, function()
    require("jc.lsp").jdtls_request(bufnr, "java/checkHashCodeEqualsStatus", range_params(), function(err, resp)
      if not resp then
        notify("checkHashCodeEqualsStatus falhou: " .. vim.inspect(err), vim.log.levels.WARN)
        return
      end

      local fields = vim.tbl_filter(function(field)
        return field.isField
      end, resp.fields or {})

      if #fields == 0 then
        notify("a classe não tem atributos para equals()/hashCode()", vim.log.levels.WARN)
        return
      end

      local function choose()
        pick_multi(
          field_items(fields),
          { title = "Java: Generate — equals() + hashCode() (selecione os campos)" },
          function(selected)
            if #selected == 0 then
              return
            end
            local chosen = {}
            for _, item in ipairs(selected) do
              chosen[#chosen + 1] = item.data
            end
            in_buffer(bufnr, function()
              with_indent(bufnr, function()
                require("jc.jdtls").generate_hashCodeAndEquals(chosen)
              end)
            end, state.tick)
          end
        )
      end

      if has_method(state.methods, "hashCode") or has_method(state.methods, "equals") then
        confirm_replace("equals()/hashCode()", choose)
      else
        choose()
      end
    end)
  end)
end

local function abstract_methods(state)
  in_buffer(state.bufnr, function()
    with_indent(state.bufnr, function()
      require("jc.jdtls").generate_abstractMethods(true)
    end)
  end, state.tick)
end

-- ---------- menu ----------

local function operations(state)
  local methods = state.methods or {}
  local can = jdtls_attached(state.bufnr) and state.node ~= nil
  local has_fields = #(state.ctor_fields or {}) > 0
  local has_any_field = #(state.fields or {}) > 0

  local getter, setter, both = false, false, false
  for _, entry in ipairs(state.accessors or {}) do
    if entry.generateGetter then
      getter = true
    end
    if entry.generateSetter then
      setter = true
    end
    if entry.generateGetter or entry.generateSetter then
      both = true
    end
  end

  local function reason(extra)
    if not jdtls_attached(state.bufnr) then
      return "jdtls não está anexado a este buffer"
    end
    if not state.node then
      return "nenhuma classe Java reconhecida no buffer"
    end
    return extra or "indisponível"
  end

  return {
    {
      key = "constructor",
      label = "Constructor",
      enabled = can and has_fields,
      reason = reason("classe sem atributos para construtor"),
    },
    {
      key = "default_constructor",
      label = "Default Constructor",
      enabled = can and not has_default_constructor(state.node, state.ctors),
      reason = has_default_constructor(state.node, state.ctors) and "já existe um construtor sem parâmetros"
        or reason("indisponível"),
    },
    { key = "getter", label = "Getter", enabled = can and getter, reason = reason("nenhum campo sem getter") },
    {
      key = "setter",
      label = "Setter",
      enabled = can and setter,
      reason = reason("nenhum campo sem setter (final ou já tem)"),
    },
    { key = "both", label = "Getter + Setter", enabled = can and both, reason = reason("nenhum campo disponível") },
    {
      key = "tostring",
      label = "toString()",
      enabled = can and has_any_field and not has_method(methods, "toString"),
      reason = has_method(methods, "toString") and "toString() já existe na classe" or reason("classe sem atributos"),
    },
    {
      key = "equals_hashcode",
      label = "equals() + hashCode()",
      enabled = can and has_any_field,
      reason = reason("classe sem atributos"),
    },
    {
      key = "abstract_methods",
      label = "Implement Abstract Methods",
      -- diagnósticos chegam em ondas: só marcamos "nada pendente" quando o
      -- jdtls está ocioso; caso contrário deixamos tentar (o jc avisa se não
      -- houver nada a implementar)
      enabled = can and (abstract_state(state.bufnr) ~= "none" or require("jc.lsp").jdtls_busy()),
      reason = can and "nenhum método abstrato pendente" or reason("indisponível"),
    },
  }
end

local RUNNERS = {
  constructor = function(state)
    constructor(state, false)
  end,
  default_constructor = function(state)
    constructor(state, true)
  end,
  getter = function(state)
    accessors(state, "get")
  end,
  setter = function(state)
    accessors(state, "set")
  end,
  both = function(state)
    accessors(state, "both")
  end,
  tostring = tostring_op,
  equals_hashcode = equals_hashcode,
  abstract_methods = abstract_methods,
}

---Entrada do `<leader>jg`.
function M.generate()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "java" then
    notify("Generate exige um buffer de classe Java", vim.log.levels.WARN)
    return
  end

  load_state(bufnr, function(state)
    if not ui.same_buffer(bufnr) then
      return
    end
    if not jdtls_attached(bufnr) then
      notify("jdtls não está anexado a este buffer — geração desabilitada", vim.log.levels.WARN)
    end

    ui.menu(operations(state), "Java: Generate", function(entry)
      local runner = RUNNERS[entry.key]
      if runner then
        runner(state)
      end
    end)
  end)
end

-- expostos para testes
M._operations = operations
M._load_state = load_state

return M

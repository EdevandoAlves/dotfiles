-- java_menu/signature.lua
-- Change Method Signature sobre a API do jdtls:
--   java/getChangeSignatureInfo  -> assinatura atual
--   java/getRefactorEdit (command="changeSignature", 8 argumentos)
-- O edit devolvido vai para java_menu.preview (nada é aplicado aqui).

local ui = require("java_menu.ui")
local lsp = require("java_menu.lsp")

local M = {}

local INDEX_FOR_ADDED = -1

local function copy_params(list)
  local out = {}
  for _, p in ipairs(list or {}) do
    out[#out + 1] =
      { type = p.type, name = p.name, defaultValue = p.defaultValue or "", originalIndex = p.originalIndex }
  end
  return out
end

local function signature_text(state)
  local parts = {}
  for _, p in ipairs(state.params) do
    parts[#parts + 1] = p.type .. " " .. p.name
  end
  local mod = state.modifier ~= "" and (state.modifier .. " ") or ""
  return ("%s%s(%s) → %s"):format(mod, state.method_name, table.concat(parts, ", "), state.return_type)
end

local function params_equal(a, b)
  if #a ~= #b then
    return false
  end
  for i = 1, #a do
    if a[i].type ~= b[i].type or a[i].name ~= b[i].name or a[i].originalIndex ~= b[i].originalIndex then
      return false
    end
  end
  return true
end

local function changed(state)
  local info = state.info
  if
    state.method_name ~= info.methodName
    or state.return_type ~= info.returnType
    or state.modifier ~= info.modifier
  then
    return true
  end
  return not params_equal(state.params, copy_params(info.parameters))
end

---Valor sugerido para as chamadas quando um parâmetro é adicionado.
local function suggested_default(typ)
  if typ == "boolean" then
    return "false"
  end
  if typ == "byte" or typ == "short" or typ == "int" or typ == "long" then
    return "0"
  end
  if typ == "double" or typ == "float" then
    return "0.0"
  end
  if typ == "char" then
    return "' '"
  end
  return "null"
end

local function valid_name(name)
  return name ~= "" and name:match("^[%a_$][%w_$]*$") ~= nil
end

---Envia a nova assinatura ao jdtls e devolve o WorkspaceEdit (sem aplicar).
local function request_edit(state, bufnr, on_edit)
  local client, client_reason = lsp.client_or_reason(bufnr)
  if not client then
    ui.notify(client_reason or "jdtls não está anexado a este buffer", vim.log.levels.ERROR)
    return
  end
  if not ui.same_buffer(bufnr) then
    return
  end
  if state.tick and vim.b[bufnr].changedtick ~= state.tick then
    ui.notify("o buffer mudou durante a edição da assinatura — refaça a operação", vim.log.levels.WARN)
    return
  end

  local params = {}
  for _, p in ipairs(state.params) do
    params[#params + 1] = {
      type = p.type,
      name = p.name,
      defaultValue = p.defaultValue or "",
      originalIndex = p.originalIndex,
    }
  end

  local args = {
    state.info.methodIdentifier,
    state.delegate,
    state.method_name,
    state.modifier,
    state.return_type,
    params,
    state.info.exceptions or {},
    false, -- change annotations
  }

  client:request("java/getRefactorEdit", {
    command = "changeSignature",
    commandArguments = args,
    context = state.context,
    options = { tabSize = vim.lsp.util.get_effective_tabstop(), insertSpaces = vim.bo[bufnr].expandtab },
  }, function(err, result)
    vim.schedule(function()
      if err then
        ui.notify("change signature recusada: " .. (err.message or vim.inspect(err)), vim.log.levels.ERROR)
        return
      end
      if not (result and result.edit) then
        ui.notify("o jdtls não retornou alterações para essa assinatura", vim.log.levels.WARN)
        return
      end
      on_edit(result.edit)
    end)
  end, bufnr)
end

local function ask_param(state, on_done)
  local entries = {}
  for i, p in ipairs(state.params) do
    entries[#entries + 1] = { label = ("%d. %s %s"):format(i, p.type, p.name), key = tostring(i) }
  end
  ui.menu(entries, "Java: Signature — parâmetro", on_done)
end

local function edit_param(state, index, reopen)
  local p = state.params[index]
  local entries = {
    { label = ("Renomear (atual: %s)"):format(p.name), key = "rename" },
    { label = ("Mudar tipo (atual: %s)"):format(p.type), key = "type" },
    { label = "Mover para cima", key = "up", enabled = index > 1, reason = "já é o primeiro" },
    { label = "Mover para baixo", key = "down", enabled = index < #state.params, reason = "já é o último" },
    { label = "Remover", key = "remove" },
  }
  ui.menu(entries, ("Java: Signature — %s %s"):format(p.type, p.name), function(entry)
    if entry.key == "rename" then
      ui.ask("Java: Signature — novo nome do parâmetro: ", p.name, function(name)
        if name == nil then
          return reopen()
        end
        name = vim.trim(name)
        if not valid_name(name) then
          ui.notify("nome inválido: " .. name, vim.log.levels.WARN)
          return reopen()
        end
        for i, other in ipairs(state.params) do
          if i ~= index and other.name == name then
            ui.notify("já existe parâmetro chamado " .. name, vim.log.levels.WARN)
            return reopen()
          end
        end
        p.name = name
        reopen()
      end)
    elseif entry.key == "type" then
      ui.ask("Java: Signature — novo tipo: ", p.type, function(typ)
        if typ == nil then
          return reopen()
        end
        typ = vim.trim(typ)
        if typ == "" then
          ui.notify("tipo vazio", vim.log.levels.WARN)
          return reopen()
        end
        p.type = typ
        reopen()
      end)
    elseif entry.key == "up" then
      state.params[index], state.params[index - 1] = state.params[index - 1], state.params[index]
      reopen()
    elseif entry.key == "down" then
      state.params[index], state.params[index + 1] = state.params[index + 1], state.params[index]
      reopen()
    elseif entry.key == "remove" then
      table.remove(state.params, index)
      reopen()
    end
  end)
end

local function open_menu(state, bufnr, on_edit)
  local entries = {
    { label = "Editar parâmetro…", key = "param", enabled = #state.params > 0, reason = "método sem parâmetros" },
    { label = "Adicionar parâmetro…", key = "add" },
    { label = "Renomear método…", key = "method_name" },
    { label = "Mudar tipo de retorno…", key = "return_type" },
    { label = "Mudar visibilidade…", key = "visibility" },
    {
      label = "Delegar assinatura antiga (@Deprecated): " .. (state.delegate and "sim" or "não"),
      key = "delegate",
    },
    {
      label = "✔ Aplicar mudança de assinatura",
      key = "apply",
      enabled = changed(state),
      reason = "assinatura inalterada",
    },
    { label = "✖ Cancelar", key = "cancel" },
  }

  ui.menu(entries, "Java: Signature — " .. signature_text(state), function(entry)
    local reopen = function()
      open_menu(state, bufnr, on_edit)
    end

    if entry.key == "param" then
      ask_param(state, function(picked)
        local index = tonumber(picked.key)
        if index then
          edit_param(state, index, reopen)
        end
      end)
    elseif entry.key == "add" then
      ui.ask("Java: Signature — novo parâmetro (tipo nome): ", "", function(value)
        if value == nil then
          return reopen()
        end
        local typ, name = vim.trim(value):match("^(.-)%s+([%w_$]+)$")
        if not typ or typ == "" or not valid_name(name) then
          ui.notify("use o formato: tipo nome", vim.log.levels.WARN)
          return reopen()
        end
        for _, other in ipairs(state.params) do
          if other.name == name then
            ui.notify("já existe parâmetro chamado " .. name, vim.log.levels.WARN)
            return reopen()
          end
        end
        ui.ask("Java: Signature — valor nas chamadas existentes: ", suggested_default(typ), function(def)
          if def == nil then
            return reopen()
          end
          def = vim.trim(def)
          if def == "" then
            def = suggested_default(typ)
          end
          state.params[#state.params + 1] = {
            type = typ,
            name = name,
            defaultValue = def,
            originalIndex = INDEX_FOR_ADDED,
          }
          reopen()
        end)
      end)
    elseif entry.key == "method_name" then
      ui.ask("Java: Signature — novo nome do método: ", state.method_name, function(name)
        if name == nil then
          return reopen()
        end
        name = vim.trim(name)
        if not valid_name(name) then
          ui.notify("nome inválido: " .. name, vim.log.levels.WARN)
          return reopen()
        end
        state.method_name = name
        reopen()
      end)
    elseif entry.key == "return_type" then
      ui.ask("Java: Signature — novo tipo de retorno: ", state.return_type, function(typ)
        if typ == nil then
          return reopen()
        end
        typ = vim.trim(typ)
        if typ == "" then
          ui.notify("tipo vazio", vim.log.levels.WARN)
          return reopen()
        end
        state.return_type = typ
        reopen()
      end)
    elseif entry.key == "visibility" then
      ui.pick_one(
        { "public", "protected", "private", "(default)" },
        "Java: Signature — visibilidade",
        function(choice)
          state.modifier = choice == "(default)" and "" or choice
          reopen()
        end
      )
    elseif entry.key == "delegate" then
      state.delegate = not state.delegate
      reopen()
    elseif entry.key == "apply" then
      request_edit(state, bufnr, on_edit)
    end
  end)
end

---Fluxo completo: info -> menu de edição -> java/getRefactorEdit -> on_edit(edit).
---@param bufnr number
---@param on_edit fun(edit: table)
function M.change_signature(bufnr, on_edit)
  local client, client_reason = lsp.client_or_reason(bufnr)
  if not client then
    ui.notify(client_reason or "jdtls não está anexado a este buffer", vim.log.levels.ERROR)
    return
  end
  if not ui.same_buffer(bufnr) then
    return
  end

  local tick = vim.b[bufnr].changedtick
  local context = vim.lsp.util.make_range_params(0, client.offset_encoding)
  context.context = { diagnostics = {} }

  client:request("java/getChangeSignatureInfo", context, function(err, info)
    vim.schedule(function()
      if err then
        ui.notify("não consegui ler a assinatura: " .. (err.message or vim.inspect(err)), vim.log.levels.ERROR)
        return
      end
      if not info or info.errorMessage then
        ui.notify(
          "change signature indisponível: " .. tostring(info and info.errorMessage or "sem método na posição"),
          vim.log.levels.WARN
        )
        return
      end
      if not ui.same_buffer(bufnr) then
        return
      end
      if vim.b[bufnr].changedtick ~= tick then
        ui.notify("o buffer mudou desde a abertura do menu — refaça o Change Signature", vim.log.levels.WARN)
        return
      end

      local state = {
        info = info,
        context = context,
        tick = tick,
        params = copy_params(info.parameters),
        method_name = info.methodName,
        modifier = info.modifier,
        return_type = info.returnType,
        delegate = false,
      }

      open_menu(state, bufnr, on_edit)
    end)
  end, bufnr)
end

-- expostos para testes
M._changed = changed
M._signature_text = signature_text

return M

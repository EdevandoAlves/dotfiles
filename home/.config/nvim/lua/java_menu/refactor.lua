-- java_menu/refactor.lua
-- <leader>jr: refatorações locais (single-file) sobre a API do jc.nvim.
--
-- A seleção Visual é capturada ANTES de abrir o picker (buffer, modo, intervalo
-- e changedtick) e reaplicada via marcas '< / '> no momento de executar, que é
-- o que o jc/nvim lê (vim.lsp.util.make_given_range_params). Nada é reaproveitado
-- de marcas Visual antigas e nenhuma operação roda em outro buffer.

local ui = require("java_menu.ui")
local preview = require("java_menu.preview")
local project = require("java_menu.project")
local signature = require("java_menu.signature")
local lsp = require("java_menu.lsp")

local M = {}

local function encoding(bufnr)
  local client = lsp.client(bufnr)
  return lsp.encoding(client)
end

---Renomear um símbolo: prepareRename (validação) + novo nome + textDocument/rename.
---O edit NUNCA é aplicado aqui: vai para a prévia.
local function rename_symbol(bufnr)
  if not ui.same_buffer(bufnr) then
    return
  end

  local current = vim.fn.expand("<cword>")
  local tick = vim.b[bufnr].changedtick
  ui.ask("Java: Refactor — novo nome: ", current, function(name)
    if name == nil then
      return
    end
    name = vim.trim(name)
    if name == "" or name == current then
      return
    end
    if not name:match("^[%a_$][%w_$]*$") then
      ui.notify("nome inválido: " .. name, vim.log.levels.WARN)
      return
    end
    if not ui.same_buffer(bufnr) then
      return
    end
    if vim.b[bufnr].changedtick ~= tick then
      ui.notify("o buffer mudou desde o rename — refaça a operação", vim.log.levels.WARN)
      return
    end

    local client, client_reason = lsp.client_or_reason(bufnr)
    if not client then
      ui.notify(client_reason or "jdtls não está anexado a este buffer", vim.log.levels.ERROR)
      return
    end

    local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
    params.newName = name

    client:request("textDocument/rename", params, function(err, edit)
      vim.schedule(function()
        if err then
          ui.notify("rename recusado pelo jdtls: " .. (err.message or vim.inspect(err)), vim.log.levels.ERROR)
          return
        end
        if type(edit) ~= "table" or not next(edit) then
          ui.notify("o jdtls não retornou alterações para esse rename", vim.log.levels.WARN)
          return
        end
        M.preview_edit(edit, bufnr)
      end)
    end, bufnr)
  end)
end

---Rótulo de destino do Move Class. Inclui o source root porque o mesmo package
---existe em src/main, src/test e em cada módulo do projeto.
---@param project_root string|nil
---@param dest table
---@return string label, string dir
local function destination_label(project_root, dest)
  local dir = vim.uri_to_fname(dest.uri)
  local name = dest.isDefaultPackage and "(default package)" or (dest.displayName or "")
  local where = (project_root and vim.fs.relpath(project_root, dir)) or dir
  return name .. "  [" .. where .. "]", dir
end

M._destination_label = destination_label

---Move Class: getMoveDestinations -> destino -> java/move (retorna o edit) -> prévia.
local function move_class(bufnr)
  if not ui.same_buffer(bufnr) then
    return
  end

  local client, client_reason = lsp.client_or_reason(bufnr)
  if not client then
    ui.notify(client_reason or "jdtls não está anexado a este buffer", vim.log.levels.ERROR)
    return
  end

  local uri = vim.uri_from_bufnr(bufnr)
  local file_name = vim.fn.fnamemodify(vim.uri_to_fname(uri), ":t")
  local tick = vim.b[bufnr].changedtick
  local project_root = project.root(bufnr)

  client:request("java/getMoveDestinations", {
    moveKind = "moveResource",
    sourceUris = { uri },
    params = vim.NIL,
  }, function(err, result)
    vim.schedule(function()
      if err then
        ui.notify("não consegui listar destinos: " .. (err.message or vim.inspect(err)), vim.log.levels.ERROR)
        return
      end
      local destinations = result and result.destinations or {}
      if #destinations == 0 then
        ui.notify("o jdtls não ofereceu destinos para esta classe", vim.log.levels.WARN)
        return
      end

      local current_dir = vim.fs.dirname(vim.uri_to_fname(uri))
      local labels, by_label, usable = {}, {}, 0

      for _, dest in ipairs(destinations) do
        local text, dir = destination_label(project_root, dest)
        if by_label[text] then
          local n = 2
          while by_label[text .. "  #" .. n] do
            n = n + 1
          end
          text = text .. "  #" .. n
        end

        local reason
        if dir == current_dir then
          reason = "já é o package atual"
        elseif vim.fn.filereadable(dir .. "/" .. file_name) == 1 then
          reason = "já existe " .. file_name .. " nesse package"
        end

        if reason then
          text = text .. "  (indisponível: " .. reason .. ")"
        else
          usable = usable + 1
        end

        labels[#labels + 1] = text
        by_label[text] = { dest = dest, reason = reason }
      end

      if usable == 0 then
        ui.notify("nenhum package de destino disponível", vim.log.levels.WARN)
        return
      end

      ui.pick_one(labels, "Java: Refactor — mover " .. file_name .. " para", function(choice)
        local picked = by_label[choice]
        if not picked then
          return
        end
        if picked.reason then
          ui.notify(picked.reason, vim.log.levels.WARN)
          return
        end
        if not ui.same_buffer(bufnr) then
          return
        end
        if vim.b[bufnr].changedtick ~= tick then
          ui.notify("o buffer mudou desde a abertura do menu — refaça o Move Class", vim.log.levels.WARN)
          return
        end

        local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
        params.context = { diagnostics = {} }

        client:request("java/move", {
          moveKind = "moveResource",
          sourceUris = { uri },
          params = params,
          destination = picked.dest,
          updateReferences = true,
        }, function(move_err, move_result)
          vim.schedule(function()
            if move_err then
              ui.notify("move recusado: " .. (move_err.message or vim.inspect(move_err)), vim.log.levels.ERROR)
              return
            end
            if move_result and move_result.errorMessage then
              ui.notify("move recusado: " .. move_result.errorMessage, vim.log.levels.ERROR)
              return
            end
            if not (move_result and move_result.edit) then
              ui.notify("o jdtls não retornou alterações para o move", vim.log.levels.WARN)
              return
            end
            M.preview_edit(move_result.edit, bufnr)
          end)
        end, bufnr)
      end)
    end)
  end, bufnr)
end

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

---Extract no cursor (sem seleção Visual): o jc usa vim.ui.select quando o
---jdtls infere mais de uma expressão. Aqui a única diferença é o seletor
---Snacks; o pedido e a aplicação do edit seguem o protocolo do jc, com
---checagem de buffer/tick antes de alterar. Qualquer falha de inferência volta
---para o fluxo do jc (mesmas mensagens).
local EXTRACT_CURSOR = {
  extract_variable = "extractVariable",
  extract_variable_all = "extractVariableAllOccurrence",
  extract_constant = "extractConstant",
}

---@param fn_name string
---@param bufnr number
local function run_extract_cursor(fn_name, bufnr)
  local jc = require("jc.refactor")
  local command = EXTRACT_CURSOR[fn_name]
  if not command or type(jc[fn_name]) ~= "function" then
    return
  end
  if not ui.same_buffer(bufnr) then
    return
  end

  local client, client_reason = lsp.client_or_reason(bufnr)
  if not client then
    ui.notify(client_reason or "jdtls não está anexado a este buffer", vim.log.levels.ERROR)
    return
  end

  local function jc_fallback()
    local guard = lsp.jc_global_reason("Extract")
    if guard then
      ui.notify(guard, vim.log.levels.WARN)
      return
    end
    return jc[fn_name](false)
  end

  local tick = vim.b[bufnr].changedtick
  local encoding = client.offset_encoding
  local context = vim.lsp.util.make_range_params(0, encoding)
  context.context = { diagnostics = {} }
  local params = {
    command = command,
    context = context,
    options = {
      tabSize = vim.lsp.util.get_effective_tabstop(),
      insertSpaces = vim.bo.expandtab,
    },
  }

  local function execute(selection)
    if not ui.same_buffer(bufnr) then
      return
    end
    if vim.b[bufnr].changedtick ~= tick then
      ui.notify("o buffer mudou durante a extração — refaça a operação", vim.log.levels.WARN)
      return
    end
    params.commandArguments = { selection }
    client:request("java/getRefactorEdit", params, function(err, result)
      vim.schedule(function()
        if err then
          ui.notify("extração recusada pelo jdtls: " .. (err.message or vim.inspect(err)), vim.log.levels.ERROR)
          return
        end
        if type(result) ~= "table" then
          return
        end
        if result.edit then
          vim.lsp.util.apply_workspace_edit(result.edit, encoding)
        end
        if result.command then
          client:request("workspace/executeCommand", result.command, function() end, bufnr)
        end
      end)
    end, bufnr)
  end

  client:request("java/inferSelection", params, function(err, selections)
    vim.schedule(function()
      if err or type(selections) ~= "table" or #selections == 0 then
        return jc_fallback()
      end
      if #selections == 1 then
        return execute(selections[1])
      end

      local labels, by_label = {}, {}
      for index, selection in ipairs(selections) do
        local label = (selection.name or ("seleção " .. index))
          .. "  ("
          .. tostring(selection.length or "?")
          .. " chars)"
        labels[#labels + 1] = label
        by_label[label] = selection
      end
      ui.pick_one(labels, "Java: Refactor — extrair (escolha a expressão)", function(choice)
        local selection = by_label[choice]
        if selection then
          execute(selection)
        end
      end)
    end)
  end, bufnr)
end

---@param fn_name string extract_variable | extract_variable_all | extract_constant | extract_method
local function run_extract(ctx, fn_name)
  local jc = require("jc.refactor")
  if ctx then
    -- o fluxo Visual usa jc.refactor, que resolve o cliente globalmente
    local guard = lsp.jc_global_reason("Extract (Visual)")
    if guard then
      ui.notify(guard, vim.log.levels.WARN)
      return
    end
    with_selection(ctx, function()
      jc[fn_name](true)
    end)
  else
    run_extract_cursor(fn_name, M._bufnr or vim.api.nvim_get_current_buf())
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
    local guard = lsp.jc_global_reason("Static Import")
    if guard then
      ui.notify(guard, vim.log.levels.WARN)
      return
    end
    require("jc.jdtls").convert_static_import(true)
  end,
  static_import_enum = function()
    local guard = lsp.jc_global_reason("Static Import Enum")
    if guard then
      ui.notify(guard, vim.log.levels.WARN)
      return
    end
    require("jc.jdtls").static_import_enum()
  end,
  flip_args = function()
    require("jc.refactor").flip_call_args()
  end,
  change_signature = function()
    signature.change_signature(M._bufnr, function(edit)
      M.preview_edit(edit, M._bufnr)
    end)
  end,
  rename = function()
    rename_symbol(M._bufnr)
  end,
  move_class = function()
    move_class(M._bufnr)
  end,
}

---@param ctx VisualCtx|nil
---@param bufnr number
---@param rename_ready boolean|nil
---@param rename_reason string|nil
local function entries(ctx, bufnr, rename_ready, rename_reason)
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
    {
      key = "rename",
      label = "Rename Symbol",
      enabled = attached and rename_ready == true,
      reason = (not attached and no_jdtls) or rename_reason or "posicione o cursor sobre um símbolo renomeável",
    },
    {
      key = "move_class",
      label = "Move Class",
      enabled = attached,
      reason = no_jdtls,
    },
    {
      key = "change_signature",
      label = "Change Method Signature",
      enabled = attached,
      reason = no_jdtls,
    },
    {
      key = "rename_package",
      label = "Rename Package",
      enabled = false,
      reason = 'o jdtls 1.63 não suporta: prepareRename responde "Renaming this element is not supported" e o rename devolve só a criação/remoção de um .temp',
    },
    {
      key = "move_package",
      label = "Move Package",
      enabled = false,
      reason = "o jdtls não expõe moveKind para packages (só moveResource para arquivos, moveInstanceMethod, moveStaticMember e moveTypeToNewFile)",
    },
  }
end

---Confirma que o jdtls importou todos os módulos do agregador antes de uma
---refatoração que pode cruzar módulos. Devolve nil quando está tudo coberto.
local function coverage_problem(bufnr, cb)
  local root = project.root(bufnr)
  if not root then
    return cb(nil)
  end

  local modules = project.modules(root)
  if #modules <= 1 then
    return cb(nil) -- projeto single-module: cobertura é o próprio root
  end

  local client = lsp.client_or_reason(bufnr)
  if not client then
    return cb("jdtls não está anexado a este buffer")
  end

  client:request(
    "workspace/executeCommand",
    { command = "java.project.listSourcePaths", arguments = {} },
    function(err, res)
      vim.schedule(function()
        if err or type(res) ~= "table" or type(res.data) ~= "table" then
          return cb("não consegui confirmar quais módulos o jdtls importou")
        end

        local paths = {}
        for _, entry in ipairs(res.data) do
          if type(entry.path) == "string" then
            paths[#paths + 1] = entry.path
          end
        end

        local missing = {}
        for _, mod in ipairs(modules) do
          local found = false
          for _, path in ipairs(paths) do
            if path == mod or path:sub(1, #mod + 1) == mod .. "/" then
              found = true
              break
            end
          end
          if not found then
            missing[#missing + 1] = vim.fs.basename(mod)
          end
        end

        if #missing > 0 then
          return cb(
            "módulos não importados pelo jdtls: "
              .. table.concat(missing, ", ")
              .. " — abra um arquivo deles (ou reinicie o Neovim) antes de refatorar"
          )
        end
        cb(nil)
      end)
    end,
    bufnr
  )
end

---Prévia real de um WorkspaceEdit (rename/move/change signature) antes de
---qualquer alteração.
function M.preview_edit(edit, bufnr)
  local root = project.root(bufnr)
  if not root then
    ui.notify("fora de um projeto Java (pom/gradle): refatoração bloqueada", vim.log.levels.WARN)
    return
  end

  coverage_problem(bufnr, function(problem)
    if problem then
      ui.notify("refatoração bloqueada: " .. problem, vim.log.levels.ERROR)
      return
    end

    local plan, err = preview.plan(edit, { encoding = encoding(bufnr), root = root })
    if not plan then
      ui.notify("prévia bloqueada: " .. err, vim.log.levels.ERROR)
      return
    end

    preview.review(plan, function() end)
  end)
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

  M._bufnr = bufnr

  -- valida rename na posição atual (assíncrono) antes de montar o menu
  local function open(rename_ready, rename_reason)
    if not ui.same_buffer(bufnr) then
      return
    end
    ui.menu(entries(ctx, bufnr, rename_ready, rename_reason), "Java: Refactor", function(entry)
      local runner = RUNNERS[entry.key]
      if runner then
        runner(ctx)
      end
    end)
  end

  if not ui.jdtls_attached(bufnr) then
    open(false, "jdtls não está anexado a este buffer")
    return
  end

  local client, client_reason = lsp.client_or_reason(bufnr)
  if not client then
    ui.notify(client_reason or "jdtls não está anexado a este buffer", vim.log.levels.WARN)
    return
  end

  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  client:request("textDocument/prepareRename", params, function(err, result)
    vim.schedule(function()
      if err then
        open(false, "rename indisponível: " .. (err.message or vim.inspect(err)))
      elseif type(result) ~= "table" then
        open(false, "jdtls não reconhece um símbolo renomeável na posição do cursor")
      else
        open(true, nil)
      end
    end)
  end, bufnr)
end

-- expostos para testes
M._capture_visual = capture_visual
M._entries = entries

return M

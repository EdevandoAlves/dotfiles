-- java_menu/preview.lua
-- Prévia e aplicação de WorkspaceEdit (rename/move) sem tocar em nada antes
-- da aprovação do usuário.
--
-- Fluxo: normalize(edit) -> plan -> review (menu + diffs) -> apply
-- A prévia é calculada em buffers temporários (nunca no buffer real nem no
-- disco). A aplicação revalida ticks/conteúdo e só então altera buffers/arquivos.

local ui = require("java_menu.ui")

local M = {}

-- ---------- helpers ----------

---Normaliza com realpath quando possível; para caminho ainda inexistente,
---resolve o diretório real e mantém o basename (rename destino).
---@param path string
---@return string
local function real_path(path)
  local real = vim.uv.fs_realpath(path)
  if real then
    return vim.fs.normalize(real)
  end
  local dir = vim.fs.dirname(path)
  local real_dir = vim.uv.fs_realpath(dir)
  if real_dir then
    return vim.fs.normalize(vim.fs.joinpath(real_dir, vim.fs.basename(path)))
  end
  return vim.fs.normalize(path)
end

---Limite real de diretório: `/tmp/proj` não aceita `/tmp/proj2`.
---@param root string
---@param path string
---@return boolean
local function inside_project(root, path)
  if type(root) ~= "string" or type(path) ~= "string" then
    return false
  end
  local real_root = real_path(root)
  local real_path = real_path(path)
  if real_root == "" or real_path == "" then
    return false
  end
  if real_root == real_path then
    return true
  end
  local sep = real_root:sub(-1) == "/" and "" or "/"
  return real_path:sub(1, #real_root + #sep) == real_root .. sep
end

---Buffer modificado apontando para `path`, mesmo quando o arquivo não existe.
---@param path string
---@return integer|nil
local function modified_buffer_for(path)
  local target = vim.fs.normalize(path)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" and vim.fs.normalize(name) == target then
        return buf
      end
    end
  end
end

local function path_of(uri)
  return vim.uri_to_fname(uri)
end

local function relpath(root, path)
  return vim.fs.relpath(root, path) or path
end

---Conteúdo atual do documento: buffer (se carregado) ou arquivo.
---@return string[]|nil lines, number|nil bufnr, number|nil tick
local function current_lines(path)
  local buf = vim.fn.bufnr(path)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false), buf, vim.b[buf].changedtick
  end
  if vim.fn.filereadable(path) == 1 then
    return vim.fn.readfile(path), nil, nil
  end
  return nil, nil, nil
end

---Aplica text edits num buffer descartável e devolve as linhas resultantes.
local function after_lines(lines, edits, encoding)
  local scratch = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(scratch, 0, -1, false, lines)
  local ok, err = pcall(vim.lsp.util.apply_text_edits, edits, scratch, encoding)
  local result
  if ok then
    result = vim.api.nvim_buf_get_lines(scratch, 0, -1, false)
  end
  pcall(vim.api.nvim_buf_delete, scratch, { force = true })
  if not ok then
    return nil, tostring(err)
  end
  return result
end

---Diff unificado + contagem de linhas.
local function make_diff(before, after, root, path)
  local unified = vim.diff(table.concat(before, "\n") .. "\n", table.concat(after, "\n") .. "\n", {
    result_type = "unified",
    ctxlen = 3,
  })
  local lines
  if type(unified) == "string" then
    lines = vim.split(unified, "\n", { plain = true })
  else
    lines = unified or {}
  end

  local header = { "--- a/" .. relpath(root, path), "+++ b/" .. relpath(root, path) }
  local added, removed = 0, 0
  for _, line in ipairs(lines) do
    if line:sub(1, 3) ~= "+++" and line:sub(1, 3) ~= "---" then
      if line:sub(1, 1) == "+" then
        added = added + 1
      elseif line:sub(1, 1) == "-" then
        removed = removed + 1
      end
    end
  end
  return vim.list_extend(header, lines), added, removed
end

-- ---------- normalização ----------

---Normaliza um WorkspaceEdit em uma lista ordenada de operações.
---Operação desconhecida (ou campo inesperado) bloqueia tudo.
---@param edit table
---@param opts { encoding: string, root: string }
---@return table|nil plan ou nil + motivo
function M.plan(edit, opts)
  if type(edit) ~= "table" then
    return nil, "WorkspaceEdit vazio"
  end
  if edit.command ~= nil then
    return nil, "o servidor pediu um comando adicional (efeito colateral não previsto)"
  end

  local ops = {}

  local function push_edit(uri, edits)
    if type(uri) ~= "string" or type(edits) ~= "table" then
      return "TextDocumentEdit inválido"
    end
    for _, edit_item in ipairs(edits) do
      if type(edit_item) ~= "table" or not edit_item.range or edit_item.newText == nil then
        return "TextEdit inválido (sem range/newText)"
      end
    end
    ops[#ops + 1] = { kind = "edit", uri = uri, path = path_of(uri), edits = edits }
  end

  local document_changes = edit.documentChanges
  if type(document_changes) == "table" and #document_changes > 0 then
    for _, change in ipairs(document_changes) do
      if type(change) ~= "table" then
        return nil, "documentChanges com entrada inválida"
      end
      if change.kind == "create" then
        ops[#ops + 1] = { kind = "create", uri = change.uri, path = path_of(change.uri) }
      elseif change.kind == "rename" then
        ops[#ops + 1] = {
          kind = "rename",
          old_uri = change.oldUri,
          new_uri = change.newUri,
          old_path = path_of(change.oldUri),
          new_path = path_of(change.newUri),
        }
      elseif change.kind == "delete" then
        ops[#ops + 1] = { kind = "delete", uri = change.uri, path = path_of(change.uri) }
      elseif change.kind == nil and change.textDocument and change.edits then
        local err = push_edit(change.textDocument.uri, change.edits)
        if err then
          return nil, err
        end
      else
        return nil, "operação não suportada no WorkspaceEdit: " .. tostring(change.kind)
      end
    end
  elseif type(edit.changes) == "table" and next(edit.changes) ~= nil then
    for uri, edits in pairs(edit.changes) do
      local err = push_edit(uri, edits)
      if err then
        return nil, err
      end
    end
    table.sort(ops, function(a, b)
      return a.path < b.path
    end)
  else
    return nil, "WorkspaceEdit sem changes/documentChanges"
  end

  -- destinos de rename: um edit pode apontar para o caminho novo, que ainda
  -- não existe no disco (o jdtls manda o edit antes do RenameFile)
  local rename_targets = {}
  for _, op in ipairs(ops) do
    if op.kind == "rename" then
      rename_targets[op.new_path] = op.old_path
    end
  end

  -- arquivos com edits: calcula antes/depois sem tocar em nada
  local files = {}
  for _, op in ipairs(ops) do
    if op.kind == "edit" then
      local source_path = op.path
      if vim.fn.filereadable(op.path) == 0 and rename_targets[op.path] then
        source_path = rename_targets[op.path]
        op.rename_from = source_path
      end
      op.source_path = source_path

      local before, bufnr, tick = current_lines(source_path)
      if not before then
        return nil, "documento não encontrado: " .. op.path
      end
      local after, err = after_lines(before, op.edits, opts.encoding)
      if not after then
        return nil, "falha ao calcular a prévia de " .. op.path .. ": " .. err
      end
      op.after_lines = after
      local diff, added, removed = make_diff(before, after, opts.root, op.path)
      files[#files + 1] = {
        path = op.path,
        source_path = source_path,
        rename_from = op.rename_from,
        uri = op.uri,
        before = before,
        after = after,
        diff = diff,
        added = added,
        removed = removed,
        bufnr = bufnr,
        tick = tick,
        edits = op.edits,
      }
    end
  end

  return { root = opts.root, encoding = opts.encoding, ops = ops, files = files }
end

-- ---------- UI ----------

local function file_label(plan, file)
  return string.format("M  %s  (+%d/-%d)", relpath(plan.root, file.path), file.added, file.removed)
end

local function op_label(plan, op)
  if op.kind == "rename" then
    return string.format("R  %s → %s", relpath(plan.root, op.old_path), relpath(plan.root, op.new_path))
  elseif op.kind == "create" then
    return string.format("C  %s (novo)", relpath(plan.root, op.path))
  elseif op.kind == "delete" then
    return string.format("D  %s", relpath(plan.root, op.path))
  end
end

---Abre o diff (somente leitura) num split; `on_close` roda ao fechar.
local function show_diff(plan, file, on_close)
  local prev_win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, file.diff)
  vim.bo[buf].filetype = "diff"
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = false
  vim.api.nvim_buf_set_name(buf, "java-preview://" .. relpath(plan.root, file.path))

  vim.cmd("sbuffer " .. buf)
  local win = vim.api.nvim_get_current_win()
  vim.wo[win].wrap = false

  local function close()
    pcall(vim.api.nvim_win_close, win, true)
    if vim.api.nvim_win_is_valid(prev_win) then
      pcall(vim.api.nvim_set_current_win, prev_win)
    end
    on_close()
  end

  vim.keymap.set("n", "q", close, { buffer = buf, desc = "Fechar prévia" })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, desc = "Fechar prévia" })
end

---Menu de revisão. Loop até Aplicar ou cancelar.
---@param plan table
---@param on_done fun(applied: boolean)
function M.review(plan, on_done)
  local function open()
    local entries = {}

    for _, file in ipairs(plan.files) do
      entries[#entries + 1] = { label = file_label(plan, file), key = "file", file = file, enabled = true }
    end
    for _, op in ipairs(plan.ops) do
      if op.kind ~= "edit" then
        entries[#entries + 1] = {
          label = op_label(plan, op),
          key = "fileop",
          enabled = false,
          reason = "operação de arquivo (executada só na confirmação)",
        }
      end
    end
    entries[#entries + 1] = { label = "✔ Aplicar alterações", key = "apply", enabled = true }
    entries[#entries + 1] = { label = "✖ Cancelar", key = "cancel", enabled = true }

    ui.menu(entries, "Java: Preview — alterações", function(entry)
      if entry.key == "cancel" then
        ui.notify("refatoração cancelada; nada foi alterado", vim.log.levels.INFO)
        on_done(false)
        return
      end
      if entry.key == "apply" then
        local result, problems = M.apply(plan)
        if not result then
          ui.notify("não apliquei: " .. table.concat(problems, "; "), vim.log.levels.ERROR)
          return
        end
        if result.error then
          ui.notify(
            "aplicação parcial: "
              .. result.error
              .. (
                result.applied and #result.applied > 0 and (" | já aplicado: " .. table.concat(result.applied, ", "))
                or ""
              ),
            vim.log.levels.ERROR
          )
          on_done(true)
          return
        end
        local parts = {}
        if #plan.files > 0 then
          parts[#parts + 1] = string.format("%d arquivo(s) com buffer modificado (use :wa para salvar)", #plan.files)
        end
        local fileops = 0
        for _, op in ipairs(plan.ops) do
          if op.kind ~= "edit" then
            fileops = fileops + 1
          end
        end
        if fileops > 0 then
          parts[#parts + 1] = string.format("%d operação(ões) de arquivo aplicada(s)", fileops)
        end
        ui.notify("aplicado: " .. table.concat(parts, " · "))
        on_done(true)
        return
      end
      -- arquivo: mostra o diff e volta ao menu
      show_diff(plan, entry.file, open)
    end)
  end

  open()
end

-- ---------- aplicação ----------

local function resolve_renames(plan)
  local map = {}
  for _, op in ipairs(plan.ops) do
    if op.kind == "rename" then
      map[op.old_path] = op.new_path
    end
  end
  return map
end

local function revalidate(plan)
  local problems = {}
  local renames = resolve_renames(plan)

  for _, file in ipairs(plan.files) do
    local path = file.source_path or file.path
    if renames[path] then
      path = renames[path]
    end
    if file.bufnr and vim.api.nvim_buf_is_valid(file.bufnr) then
      if vim.b[file.bufnr].changedtick ~= file.tick then
        problems[#problems + 1] = "buffer alterado desde a prévia: " .. relpath(plan.root, path)
      end
    else
      local now = vim.fn.filereadable(file.source_path or file.path) == 1
          and vim.fn.readfile(file.source_path or file.path)
        or nil
      if not now or table.concat(now, "\n") ~= table.concat(file.before, "\n") then
        problems[#problems + 1] = "arquivo alterado desde a prévia: " .. relpath(plan.root, path)
      end
    end
  end

  for _, op in ipairs(plan.ops) do
    if op.kind == "rename" then
      if vim.fn.filereadable(op.old_path) == 0 then
        problems[#problems + 1] = "origem não existe: " .. relpath(plan.root, op.old_path)
      end
      if vim.fn.filereadable(op.new_path) == 1 then
        problems[#problems + 1] = "destino já existe: " .. relpath(plan.root, op.new_path)
      end
      if vim.fn.isdirectory(vim.fs.dirname(op.new_path)) == 0 then
        problems[#problems + 1] = "diretório destino não existe: " .. relpath(plan.root, vim.fs.dirname(op.new_path))
      end
      local stale = modified_buffer_for(op.new_path)
      if stale then
        problems[#problems + 1] = "o destino tem buffer modificado não salvo: "
          .. relpath(plan.root, op.new_path)
          .. " — feche/salve esse buffer antes de aplicar"
      end
    elseif op.kind == "create" then
      if vim.fn.filereadable(op.path) == 1 then
        problems[#problems + 1] = "arquivo já existe: " .. relpath(plan.root, op.path)
      end
    elseif op.kind == "delete" then
      if vim.fn.filereadable(op.path) == 0 then
        problems[#problems + 1] = "arquivo não existe: " .. relpath(plan.root, op.path)
      end
    end
  end

  -- tudo dentro do projeto
  for _, op in ipairs(plan.ops) do
    local paths = {}
    if op.kind == "rename" then
      paths = { op.old_path, op.new_path }
    else
      paths = { op.path }
    end
    for _, path in ipairs(paths) do
      if not inside_project(plan.root, path) then
        problems[#problems + 1] = "fora do projeto: " .. path
      end
    end
  end

  return problems
end

local function buffer_for(path)
  local buf = vim.fn.bufnr(path)
  if buf == -1 then
    buf = vim.fn.bufadd(path)
    vim.fn.bufload(buf)
  end
  return buf
end

---Conteúdo final calculado na prévia para o documento que está sendo renomeado.
local function after_for(plan, old_path)
  for _, file in ipairs(plan.files or {}) do
    if file.source_path == old_path then
      return file.after
    end
  end
end

local function apply_op(op, plan, renamed)
  if op.kind == "edit" then
    -- se o documento já foi renomeado, aplica no caminho novo; caso contrário
    -- no buffer de origem (o rename posterior leva o buffer junto)
    local path = renamed[op.path] or op.source_path or op.path
    local buf = buffer_for(path)
    vim.lsp.util.apply_text_edits(op.edits, buf, plan.encoding)
    if not vim.bo[buf].buflisted then
      vim.bo[buf].buflisted = true
    end
    return "edits " .. relpath(plan.root, path)
  elseif op.kind == "rename" then
    local ok, rc = pcall(vim.fn.rename, op.old_path, op.new_path)
    if not ok then
      error("rename falhou: " .. tostring(rc), 0)
    end
    if rc ~= 0 or vim.fn.filereadable(op.old_path) == 1 then
      error("rename falhou (permissão?): " .. relpath(plan.root, op.old_path), 0)
    end
    renamed[op.old_path] = op.new_path

    -- Alinha o buffer ao novo caminho sem gravar nada: recarrega o arquivo
    -- movido e reaplica em memória o conteúdo calculado na prévia. Assim o
    -- `:wa` do usuário grava sem pedir confirmação (b_mtime correto) e nada é
    -- salvo automaticamente.
    local old_buf = vim.fn.bufnr(op.old_path)
    if old_buf ~= -1 and vim.api.nvim_buf_is_loaded(old_buf) then
      local after = after_for(plan, op.old_path)
      local win = vim.fn.bufwinid(old_buf)
      local was_current = vim.api.nvim_get_current_buf() == old_buf
      -- o novo buffer precisa herdar os clientes LSP do buffer antigo,
      -- senão o JDTLS perde o documento após RenameFile/Move
      local old_clients = vim.lsp.get_clients({ bufnr = old_buf })

      local stale = vim.fn.bufnr(op.new_path)
      if stale ~= -1 and stale ~= old_buf and not vim.bo[stale].modified then
        pcall(vim.api.nvim_buf_delete, stale, { force = true })
      end

      pcall(vim.api.nvim_buf_delete, old_buf, { force = true })

      local new_buf
      if win ~= -1 then
        pcall(vim.api.nvim_set_current_win, win)
        vim.cmd("edit " .. vim.fn.fnameescape(op.new_path))
        new_buf = vim.api.nvim_get_current_buf()
      else
        new_buf = vim.fn.bufadd(op.new_path)
        vim.fn.bufload(new_buf)
      end

      if after then
        vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, after)
        vim.bo[new_buf].modified = true
      end
      vim.bo[new_buf].buflisted = true
      for _, client in ipairs(old_clients) do
        local attached = vim.lsp.get_clients({ bufnr = new_buf, id = client.id })
        if #attached == 0 then
          pcall(vim.lsp.buf_attach_client, new_buf, client.id)
        end
      end

      if was_current and win == -1 then
        pcall(vim.api.nvim_set_current_buf, new_buf)
      end
    end
    return "rename " .. relpath(plan.root, op.old_path) .. " → " .. relpath(plan.root, op.new_path)
  elseif op.kind == "create" then
    vim.fn.mkdir(vim.fs.dirname(op.path), "p")
    local ok, rc = pcall(vim.fn.writefile, {}, op.path)
    if not ok or rc ~= 0 or vim.fn.filereadable(op.path) == 0 then
      error("create falhou: " .. relpath(plan.root, op.path), 0)
    end
    return "create " .. relpath(plan.root, op.path)
  elseif op.kind == "delete" then
    local ok, rc = pcall(vim.fn.delete, op.path)
    if not ok or rc ~= 0 or vim.fn.filereadable(op.path) == 1 then
      error("delete falhou: " .. relpath(plan.root, op.path), 0)
    end
    local buf = vim.fn.bufnr(op.path)
    if buf ~= -1 then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
    return "delete " .. relpath(plan.root, op.path)
  end
  error("operação desconhecida: " .. tostring(op.kind), 0)
end

---Revalida e aplica. Nunca escreve buffers abertos (`:wa` é do usuário).
---@return table|nil result, string[]|nil problems
function M.apply(plan)
  local problems = revalidate(plan)
  if #problems > 0 then
    return nil, problems
  end

  local applied = {}
  local renamed = {}
  for _, op in ipairs(plan.ops) do
    local ok, err = pcall(apply_op, op, plan, renamed)
    if not ok then
      return { applied = applied, error = tostring(err) }
    end
    applied[#applied + 1] = err
  end
  return { applied = applied }
end

-- expostos para testes
M._revalidate = revalidate
M._show_diff = show_diff
M._inside_project = inside_project
M._modified_buffer_for = modified_buffer_for

return M

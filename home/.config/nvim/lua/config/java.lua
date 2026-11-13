-- config/java.lua
-- Criação de packages e tipos Java sem wizard de IDE.
--
--   :JavaNew                          fluxo interativo (tipo, source root, package, nome)
--   :JavaNew <pacote> <Nome> [tipo]   direto (use "-" como pacote default)
--   :JavaNew! ...                     sobrescreve se o arquivo já existir
--   :JavaPkg [<pacote>]               cria só o diretório do package
--
-- Tipos: class | interface | enum | record | annotation | test (JUnit 5, src/test/java)

local M = {}

M.markers = {
  "pom.xml",
  "build.gradle",
  "build.gradle.kts",
  "settings.gradle",
  "settings.gradle.kts",
  ".git",
}

M.kinds = { "class", "interface", "enum", "record", "annotation", "test" }

local labels = {
  class = "Class",
  interface = "Interface",
  enum = "Enum",
  record = "Record",
  annotation = "Annotation (@interface)",
  test = "Test (JUnit 5, src/test/java)",
}

local function notify(msg, level)
  vim.notify("Java: " .. msg, level or vim.log.levels.INFO)
end

local function is_valid_package(pkg)
  if pkg == "" then
    return true
  end
  if not pkg:match("^[%a_][%w_%.]*$") or pkg:match("%.%.") or pkg:match("%.$") then
    return false
  end
  for segment in pkg:gmatch("[^%.]+") do
    if not segment:match("^[%a_][%w_]*$") then
      return false
    end
  end
  return true
end

local function is_valid_name(name)
  return name:match("^[%a_][%w_]*$") ~= nil
end

---Raiz do projeto a partir de um arquivo/diretório.
---@param fname string|nil
---@return string
local function project_root(fname)
  fname = (fname and fname ~= "") and fname or vim.uv.cwd()
  return vim.fs.root(fname, M.markers) or vim.uv.cwd()
end
M.project_root = project_root

---Source roots disponíveis (main/test) ou a raiz como fallback.
---@param root string
---@return table[]
local function source_roots(root)
  local roots = {}
  for _, sub in ipairs({ "src/main/java", "src/test/java" }) do
    local path = root .. "/" .. sub
    if vim.fn.isdirectory(path) == 1 then
      roots[#roots + 1] = { path = path, test = sub:find("test") ~= nil, label = sub }
    end
  end
  if #roots == 0 then
    roots[1] = { path = root, test = false, label = "." }
  end
  return roots
end
M.source_roots = source_roots

---Packages já existentes sob um source root (para autocomplete).
---@param root string
---@return string[]
local function existing_packages(root)
  local seen, list = {}, {}
  local files = vim.fs.find(function(name)
    return name:sub(-5) == ".java"
  end, { path = root, type = "file", limit = 500 })

  for _, file in ipairs(files) do
    local rel = vim.fs.relpath(root, vim.fs.dirname(file))
    if rel and rel ~= "" and rel ~= "." and not rel:match("^%.%.") then
      local pkg = rel:gsub("/", ".")
      if not seen[pkg] then
        seen[pkg] = true
        list[#list + 1] = pkg
      end
    end
  end

  table.sort(list)
  return list
end
M.existing_packages = existing_packages

---Package do buffer atual, lido da primeira linha `package ...;`.
---@return string|nil
local function buffer_package()
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, 30, false)) do
    local pkg = line:match("^%s*package%s+([%w_%.]+)%s*;")
    if pkg then
      return pkg
    end
  end
end

---Esqueleto do tipo: retorna linhas e posição do cursor.
---@param kind string
---@param pkg string
---@param name string
---@return string[], integer[]
local function skeleton(kind, pkg, name)
  local lines = {}
  local function push(line)
    lines[#lines + 1] = line
    return #lines
  end

  if pkg ~= "" then
    push("package " .. pkg .. ";")
    push("")
  end

  if kind == "record" then
    local row = push("public record " .. name .. "() {")
    push("    ")
    push("}")
    return lines, { row, 15 + #name } -- dentro dos parênteses
  end

  if kind == "test" then
    local method = name:gsub("Test$", "")
    method = method:gsub("^%u", string.lower)
    if method == "" then
      method = "teste"
    end
    push("import org.junit.jupiter.api.Test;")
    push("")
    push("import static org.junit.jupiter.api.Assertions.*;")
    push("")
    push("class " .. name .. " {")
    push("")
    push("    @Test")
    push("    void " .. method .. "() {")
    local row = push("        ")
    push("    }")
    push("}")
    return lines, { row, 8 }
  end

  local header
  if kind == "interface" then
    header = "public interface "
  elseif kind == "enum" then
    header = "public enum "
  elseif kind == "annotation" then
    header = "public @interface "
  else
    header = "public class "
  end

  push(header .. name .. " {")
  local row = push("    ")
  push("}")
  return lines, { row, 4 }
end

---Cria o diretório do package e o arquivo do tipo.
---@param opts { package: string, name: string, kind: string, root: string, force: boolean|nil }
---@return string|nil file
function M.create(opts)
  local kind = opts.kind or "class"
  local pkg = opts.package or ""
  local name = opts.name

  if not vim.tbl_contains(M.kinds, kind) then
    notify("tipo desconhecido: " .. kind, vim.log.levels.ERROR)
    return
  end
  if not is_valid_package(pkg) then
    notify("package inválido: " .. pkg, vim.log.levels.ERROR)
    return
  end
  if not name or not is_valid_name(name) then
    notify("nome inválido: " .. tostring(name), vim.log.levels.ERROR)
    return
  end
  if kind == "test" and not name:match("Test$") then
    name = name .. "Test"
  end

  local dir = opts.root
  if pkg ~= "" then
    dir = dir .. "/" .. pkg:gsub("%.", "/")
  end
  local file = dir .. "/" .. name .. ".java"

  if vim.fn.filereadable(file) == 1 and not opts.force then
    notify(vim.fs.basename(file) .. " já existe", vim.log.levels.WARN)
    vim.cmd.edit(vim.fn.fnameescape(file))
    return file
  end

  pcall(vim.fn.mkdir, dir, "p")
  if vim.fn.isdirectory(dir) == 0 then
    notify("não consegui criar " .. dir, vim.log.levels.ERROR)
    return
  end

  local lines, cursor = skeleton(kind, pkg, name)
  vim.fn.writefile(lines, file)
  vim.cmd.edit(vim.fn.fnameescape(file))

  local row = math.min(cursor[1], vim.api.nvim_buf_line_count(0))
  pcall(vim.api.nvim_win_set_cursor, 0, { row, cursor[2] })
  vim.cmd("startinsert")
  notify("criado " .. (vim.fs.relpath(project_root(file), file) or file))

  return file
end

---Fluxo interativo.
function M.new()
  local root = project_root(vim.api.nvim_buf_get_name(0))
  local roots = source_roots(root)

  local options = vim.tbl_map(function(kind)
    return labels[kind]
  end, M.kinds)

  vim.ui.select(options, { prompt = "Java: criar" }, function(label)
    if not label then
      return
    end
    local kind = M.kinds[vim.fn.index(options, label) + 1]
    if not kind then
      return
    end

    local candidates = vim.tbl_filter(function(r)
      return r.test == (kind == "test")
    end, roots)
    if #candidates == 0 then
      candidates = roots
    end

    local function ask_name(source_root)
      local default_pkg = buffer_package() or ""
      vim.ui.input({
        prompt = "Package (vazio = default): ",
        default = default_pkg,
        completion = "customlist",
        completion_list = existing_packages(source_root.path),
      }, function(pkg)
        if pkg == nil then
          return
        end
        pkg = vim.trim(pkg)

        vim.ui.input({ prompt = "Nome do tipo: " }, function(name)
          if name == nil then
            return
          end
          name = vim.trim(name)
          if name == "" then
            return
          end
          M.create({ package = pkg, name = name, kind = kind, root = source_root.path })
        end)
      end)
    end

    if #candidates == 1 then
      ask_name(candidates[1])
      return
    end

    local choices = vim.tbl_map(function(r)
      return r.label
    end, candidates)
    vim.ui.select(choices, { prompt = "Source root" }, function(choice)
      if not choice then
        return
      end
      for _, r in ipairs(candidates) do
        if r.label == choice then
          ask_name(r)
          return
        end
      end
    end)
  end)
end

---Cria só o diretório do package.
---@param pkg string
---@return string|nil dir
function M.package_dir(pkg)
  if not is_valid_package(pkg) then
    notify("package inválido: " .. pkg, vim.log.levels.ERROR)
    return
  end
  local root = source_roots(project_root(vim.api.nvim_buf_get_name(0)))[1]
  local dir = root.path
  if pkg ~= "" then
    dir = dir .. "/" .. pkg:gsub("%.", "/")
  end
  pcall(vim.fn.mkdir, dir, "p")
  if vim.fn.isdirectory(dir) == 0 then
    notify("não consegui criar " .. dir, vim.log.levels.ERROR)
    return
  end
  notify("package " .. (pkg == "" and "(default)" or pkg) .. " pronto")
  return dir
end

vim.api.nvim_create_user_command("JavaNew", function(args)
  local a = args.fargs
  if #a < 2 then
    M.new()
    return
  end

  local pkg = a[1] == "-" and "" or a[1]
  local kind = a[3] or "class"
  M.create({
    package = pkg,
    name = a[2],
    kind = kind,
    root = source_roots(project_root(vim.api.nvim_buf_get_name(0)))[1].path,
    force = args.bang,
  })
end, {
  nargs = "*",
  bang = true,
  desc = "Java: criar package + tipo",
  complete = function(arg_lead, cmd_line)
    local parts = vim.split(cmd_line, "%s+", { trimempty = true })
    if #parts <= 2 then
      local root = source_roots(project_root(vim.api.nvim_buf_get_name(0)))[1]
      return vim.tbl_filter(function(p)
        return p:sub(1, #arg_lead) == arg_lead
      end, existing_packages(root.path))
    end
    if #parts == 4 then
      return vim.tbl_filter(function(k)
        return k:sub(1, #arg_lead) == arg_lead
      end, M.kinds)
    end
    return {}
  end,
})

vim.api.nvim_create_user_command("JavaPkg", function(args)
  if args.args == "" then
    vim.ui.input({ prompt = "Package: " }, function(pkg)
      if pkg and pkg ~= "" then
        M.package_dir(vim.trim(pkg))
      end
    end)
    return
  end
  M.package_dir(vim.trim(args.args))
end, { nargs = "?", desc = "Java: criar diretório de package" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "java",
  callback = function(ev)
    vim.keymap.set("n", "<leader>cj", "<cmd>JavaNew<cr>", { buffer = ev.buf, desc = "Java: novo tipo" })
  end,
})

return M

-- java_menu/project.lua
-- Detecção de projeto Java por arquivos de build (Maven/Gradle).
-- .git NÃO é considerado marcador de projeto Java.

local M = {}

M.markers = {
  "pom.xml",
  "build.gradle",
  "build.gradle.kts",
  "settings.gradle",
  "settings.gradle.kts",
}

-- arquivos que caracterizam um módulo (o settings.* só existe na raiz)
M.build_files = { "pom.xml", "build.gradle", "build.gradle.kts" }

local function isfile(path)
  return vim.fn.filereadable(path) == 1
end

local function isdir(path)
  return vim.fn.isdirectory(path) == 1
end

local function has_any(dir, list)
  for _, file in ipairs(list) do
    if isfile(dir .. "/" .. file) then
      return true
    end
  end
  return false
end

---Caminho de referência do buffer (arquivo, diretório do netrw ou cwd).
---@param buf number|nil
---@return string
function M.start_path(buf)
  buf = buf and buf > 0 and buf or vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    return vim.fs.normalize(vim.uv.cwd())
  end
  return vim.fs.normalize(name)
end

---`parent` declara `child` como módulo (Maven <module> / Gradle include)?
---@param parent string
---@param child string
---@return boolean
local function declares_module(parent, child)
  local pom = parent .. "/pom.xml"
  if isfile(pom) then
    for _, line in ipairs(vim.fn.readfile(pom)) do
      local mod = line:match("<module>%s*([^<%s]+)%s*</module>")
      if mod then
        mod = mod:gsub("/+$", "")
        if vim.fs.basename(mod) == child then
          return true
        end
      end
    end
    return false
  end

  -- Gradle: leitura tolerante de settings.gradle(.kts)
  for _, file in ipairs({ "settings.gradle", "settings.gradle.kts" }) do
    local settings = parent .. "/" .. file
    if isfile(settings) then
      local text = table.concat(vim.fn.readfile(settings), "\n")
      if
        text:find('"' .. child .. '"', 1, true)
        or text:find("'" .. child .. "'", 1, true)
        or text:find(":" .. child, 1, true)
      then
        return true
      end
    end
  end
  return false
end

---Sobe até o diretório que contém um arquivo de build.
---Em projeto multimódulo sobe até o agregador (o pai que declara o módulo).
---@param buf number|nil
---@return string|nil
function M.root(buf)
  local start = M.start_path(buf)
  local dir = isdir(start) and start or vim.fs.dirname(start)
  local found

  while dir and dir ~= "" do
    if has_any(dir, M.markers) then
      found = dir
      local parent = vim.fs.dirname(dir)
      if not parent or parent == dir then
        return found
      end
      if has_any(parent, M.markers) and declares_module(parent, vim.fs.basename(dir)) then
        dir = parent -- agrega; o source root preferido é resolvido depois
      else
        return found
      end
    else
      local parent = vim.fs.dirname(dir)
      if not parent or parent == dir then
        return nil
      end
      dir = parent
    end
  end
  return found
end

---@param buf number|nil
---@return boolean
function M.is_java_project(buf)
  return M.root(buf) ~= nil
end

---Módulos do projeto: a raiz mais os subdiretórios diretos com arquivo de build.
---@param root string
---@return string[]
local function modules(root)
  local list = { root }
  local ok, iter = pcall(vim.fs.dir, root)
  if ok then
    for name, kind in iter do
      if kind == "directory" and has_any(root .. "/" .. name, M.build_files) then
        list[#list + 1] = root .. "/" .. name
      end
    end
  end
  return list
end

---Source roots existentes (src/main/java, src/test/java) de cada módulo.
---@param root string
---@return table[] { path, module, set, label }
function M.source_roots(root)
  local out = {}
  for _, mod in ipairs(modules(root)) do
    for _, set in ipairs({ "main", "test" }) do
      local path = mod .. "/src/" .. set .. "/java"
      if isdir(path) then
        local name = vim.fs.basename(mod)
        out[#out + 1] = {
          path = path,
          module = name,
          set = set,
          -- rótulo curto; a raiz do projeto não repete o nome do módulo
          label = (mod == root and "" or (name .. " · ")) .. "src/" .. set .. "/java",
        }
      end
    end
  end
  return out
end

---Source root que contém o buffer, com preferência para src/main/java.
---@param roots table[]
---@param buf number|nil
---@return table|nil
function M.preferred(roots, buf)
  local name = M.start_path(buf)
  for _, r in ipairs(roots) do
    if r.set == "main" and name:sub(1, #r.path + 1) == r.path .. "/" then
      return r
    end
  end
  for _, r in ipairs(roots) do
    if r.set == "main" then
      return r
    end
  end
  return roots[1]
end

---Packages já existentes sob um source root (para sugestão).
---@param source_root string
---@param limit integer|nil
---@return string[]
function M.packages(source_root, limit)
  local seen, out = {}, {}
  local files = vim.fs.find(function(name)
    return name:sub(-5) == ".java"
  end, { path = source_root, type = "file", limit = 500 })

  for _, file in ipairs(files) do
    local rel = vim.fs.relpath(source_root, vim.fs.dirname(file))
    if rel and rel ~= "" and rel ~= "." and not rel:match("^%.%.") then
      local pkg = rel:gsub("/", ".")
      if not seen[pkg] then
        seen[pkg] = true
        out[#out + 1] = pkg
      end
    end
  end

  table.sort(out)
  if limit and #out > limit then
    return vim.list_slice(out, 1, limit)
  end
  return out
end

---Package sugerido para um buffer dentro de um source root.
---Também funciona para diretórios (netrw).
---@param buf number|nil
---@param source_root string
---@return string
function M.package_for(buf, source_root)
  buf = buf and buf > 0 and buf or vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    return ""
  end

  if not isdir(name) and vim.bo[buf].filetype == "java" then
    for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, 30, false)) do
      local pkg = line:match("^%s*package%s+([%w_%.]+)%s*;")
      if pkg then
        return pkg
      end
    end
  end

  local dir = isdir(name) and name or vim.fs.dirname(name)
  local rel = vim.fs.relpath(source_root, dir)
  if rel and rel ~= "" and rel ~= "." and not rel:match("^%.%.") then
    return (rel:gsub("/", "."))
  end
  return ""
end

return M

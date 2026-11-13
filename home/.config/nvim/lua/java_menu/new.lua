-- java_menu/new.lua
-- Fluxo "New" do menu <leader>j: popups centrais (Snacks) + validação + criação.
-- Usa os templates públicos do jc.nvim quando disponíveis; cai para o gerador
-- anterior (config/java.lua) se o jc não estiver carregado.

local project = require("java_menu.project")

local M = {}

---@class JavaKind
---@field label string
---@field template string template do jc.nvim
---@field legacy string tipo aceito pelo gerador anterior
---@field abstract boolean|nil

---@type JavaKind[]
M.kinds = {
  { label = "Class", template = "class", legacy = "class" },
  { label = "Abstract Class", template = "class", legacy = "class", abstract = true },
  { label = "Interface", template = "interface", legacy = "interface" },
  { label = "Enum", template = "enum", legacy = "enum" },
  { label = "Record", template = "record", legacy = "record" },
  { label = "Annotation", template = "annotation", legacy = "annotation" },
}

local OTHER_ROOT = "(outro diretório…)"

-- palavras reservadas e literais de Java (lista como string para não usar
-- palavras reservadas do Lua como chaves)
local keywords = {}
for word in
  ([[
abstract assert boolean break byte case catch char class const continue default do double else
enum extends final finally float for goto if implements import instanceof int interface long native new
package private protected public return short static strictfp super switch synchronized this throw throws
transient try var void volatile while true false null _
]]):gmatch("%S+")
do
  keywords[word] = true
end

local function notify(msg, level)
  vim.notify("Java: " .. msg, level or vim.log.levels.INFO)
end

---Seleção central (Snacks) com fallback para o vim.ui.select nativo.
---Não substitui vim.ui.select globalmente.
local function select(items, opts, on_choice)
  local ok, snacks = pcall(require, "snacks")
  if ok and snacks.picker and type(snacks.picker.select) == "function" then
    return snacks.picker.select(items, opts, on_choice)
  end
  return vim.ui.select(items, opts, on_choice)
end

---Entrada central (Snacks) com fallback para o vim.ui.input nativo.
local function input(opts, on_confirm)
  local ok, snacks = pcall(require, "snacks")
  if ok and snacks.input and type(snacks.input.input) == "function" then
    return snacks.input.input(opts, on_confirm)
  end
  return vim.ui.input(opts, on_confirm)
end

---@param name string
---@return boolean
local function is_identifier(name)
  return name:match("^[%a_$][%w_$]*$") ~= nil and not keywords[name]
end

---@param pkg string
---@return boolean
local function is_package(pkg)
  if pkg == "" then
    return true
  end
  for segment in pkg:gmatch("[^%.]+") do
    if not is_identifier(segment) then
      return false
    end
  end
  return not pkg:match("^%.") and not pkg:match("%.$") and not pkg:match("%.%.")
end

---Templates públicos do jc.nvim (módulo de dados, não inicia servidor).
local function jc_templates()
  local ok, templates = pcall(require, "jc.templates")
  if ok and type(templates.render) == "function" then
    return templates
  end
end

---@return boolean
local function jdtls_attached()
  return #vim.lsp.get_clients({ name = "jdtls" }) > 0
end

---Renderiza o tipo com o template do jc.nvim.
---@param kind JavaKind
---@param pkg string
---@param name string
---@return string|nil
local function render_jc(kind, pkg, name)
  local templates = jc_templates()
  if not templates then
    return nil
  end
  local ok, body = pcall(templates.render, kind.template, { name = name, package = pkg })
  if not ok or type(body) ~= "string" or vim.trim(body) == "" then
    return nil
  end
  if kind.abstract then
    body = body:gsub("public class ", "public abstract class ", 1)
  end
  -- os templates do jc.nvim contam com um :normal! gg=G depois; sem parser Java
  -- normalizamos aqui para um corpo vazio com uma linha em branco
  body = body:gsub("\n\n\n+", "\n\n")
  return body
end

---Cria o arquivo do tipo pedido. Nunca sobrescreve.
---@param kind JavaKind
---@param source_root string
---@param pkg string
---@param name string
---@return string|nil file
function M.create(kind, source_root, pkg, name)
  local dir = source_root
  if pkg ~= "" then
    dir = dir .. "/" .. pkg:gsub("%.", "/")
  end
  local file = dir .. "/" .. name .. ".java"
  local root = project.root() or source_root
  local rel = vim.fs.relpath(root, file) or file

  if vim.fn.filereadable(file) == 1 then
    notify("já existe, nada foi sobrescrito: " .. rel, vim.log.levels.WARN)
    vim.cmd.edit(vim.fn.fnameescape(file))
    return file
  end

  pcall(vim.fn.mkdir, dir, "p")
  if vim.fn.isdirectory(dir) == 0 then
    notify("não consegui criar o diretório " .. dir, vim.log.levels.ERROR)
    return nil
  end
  if vim.fn.filewritable(dir) ~= 2 then
    notify("diretório sem permissão de escrita: " .. dir, vim.log.levels.ERROR)
    return nil
  end

  local body = render_jc(kind, pkg, name)
  if body then
    -- :edit dispara BufNewFile, então o jc marca o arquivo como novo e
    -- atualiza o build path do jdtls no primeiro write
    vim.cmd.edit(vim.fn.fnameescape(file))
    vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(body:gsub("\n+$", ""), "\n", { plain = true }))
    vim.cmd.write()
    notify("criado " .. rel)
    return file
  end

  -- fallback: gerador anterior
  local ok, legacy = pcall(require, "config.java")
  if not ok or type(legacy.create) ~= "function" then
    notify("jc.nvim não está carregado e o gerador anterior não está disponível", vim.log.levels.ERROR)
    return nil
  end

  local created = legacy.create({ package = pkg, name = name, kind = kind.legacy, root = source_root })
  if created and kind.abstract then
    local line = vim.fn.search("^public class ", "nw")
    if line > 0 then
      vim.api.nvim_buf_set_lines(0, line - 1, line, false, { "public abstract class " .. name .. " {" })
      vim.cmd.write()
    end
  end
  return created
end

---Pergunta package (com sugestão) e nome, depois cria.
---@param kind JavaKind
---@param source_root string
---@param suggested_pkg string
local function ask(kind, source_root, suggested_pkg)
  input({ prompt = "Package (vazio = default): ", default = suggested_pkg }, function(pkg)
    if pkg == nil then
      return -- cancelado
    end
    pkg = vim.trim(pkg)
    if not is_package(pkg) then
      notify("package Java inválido: " .. pkg, vim.log.levels.WARN)
      return ask(kind, source_root, suggested_pkg)
    end

    input({ prompt = "Nome do tipo: " }, function(name)
      if name == nil then
        return -- cancelado
      end
      name = vim.trim(name)
      if not is_identifier(name) then
        notify("identificador Java inválido: " .. (name == "" and "(vazio)" or name), vim.log.levels.WARN)
        return ask(kind, source_root, pkg)
      end
      M.create(kind, source_root, pkg, name)
    end)
  end)
end

---Escolha do source root (com opção de digitar outro).
---@param kind JavaKind
---@param roots table[]
local function pick_root(kind, roots)
  local preferred = project.preferred(roots)
  local ordered = { preferred }
  for _, r in ipairs(roots) do
    if r ~= preferred then
      ordered[#ordered + 1] = r
    end
  end

  local items = {}
  for _, r in ipairs(ordered) do
    items[#items + 1] = r.label
  end
  items[#items + 1] = OTHER_ROOT

  select(items, { prompt = "Java: source root" }, function(choice)
    if choice == nil then
      return -- cancelado
    end
    if choice == OTHER_ROOT then
      input({ prompt = "Source root: ", default = preferred.path }, function(path)
        if path == nil then
          return
        end
        path = vim.fs.normalize(vim.trim(path))
        if vim.fn.isdirectory(path) == 0 then
          notify("diretório inexistente: " .. path, vim.log.levels.ERROR)
          return
        end
        ask(kind, path, project.package_for(0, path))
      end)
      return
    end
    for _, r in ipairs(ordered) do
      if r.label == choice then
        return ask(kind, r.path, project.package_for(0, r.path))
      end
    end
  end)
end

---Entrada do `<leader>jn`.
function M.new()
  local root = project.root()
  if not root then
    notify("nenhum projeto Maven/Gradle (pom.xml, build.gradle) encontrado a partir deste buffer", vim.log.levels.WARN)
    return
  end

  local roots = project.source_roots(root)
  if #roots == 0 then
    notify("projeto sem source root (src/main/java) em " .. root, vim.log.levels.WARN)
    return
  end

  if not jdtls_attached() then
    notify(
      "jdtls não está anexado — o arquivo será criado, mas autocomplete de tipos, imports automáticos e code actions ficam limitados até abrir o projeto em um buffer Java",
      vim.log.levels.WARN
    )
  end

  local labels = vim.tbl_map(function(k)
    return k.label
  end, M.kinds)

  select(labels, { prompt = "Java: New" }, function(label)
    if label == nil then
      return -- cancelado
    end
    for _, kind in ipairs(M.kinds) do
      if kind.label == label then
        return pick_root(kind, roots)
      end
    end
  end)
end

return M

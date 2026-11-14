-- java_menu/new.lua
-- Fluxo "New" do menu <leader>j: popups centrais (Snacks) + validação + criação.
-- Usa os templates públicos do jc.nvim quando disponíveis; cai para o gerador
-- anterior (config/java.lua) nos tipos básicos se o jc não estiver carregado.
--
-- Fase 5A: extends/implements/campos/componentes, templates extras do jc e
-- resumo antes de criar. A semântica de tipos vem do JDTLS (workspace/symbol);
-- os tipos escolhidos entram como FQN, então o arquivo não depende de imports
-- automáticos. Sem JDTLS, a criação básica continua e os tipos são digitados.

local project = require("java_menu.project")
local ui = require("java_menu.ui")

local M = {}

---@class JavaKind
---@field label string
---@field template string template do jc.nvim
---@field legacy string|nil tipo aceito pelo gerador anterior (sem jc)
---@field decl string "class"|"interface"|"enum"|"record"|"annotation"
---@field abstract boolean|nil
---@field extends_slot string|nil "class" (uma superclasse) | "interface" (várias)
---@field implements boolean|nil
---@field fields string|nil "fields"|"components"|"methods"|"elements"
---@field values boolean|nil
---@field requires string|nil "junit"|"spring"|"jpa"
---@field extra boolean|nil template adicional (exige jc.nvim)

---@type JavaKind[]
M.kinds = {
  {
    label = "Class",
    template = "class",
    legacy = "class",
    decl = "class",
    extends_slot = "class",
    implements = true,
    fields = "fields",
  },
  {
    label = "Abstract Class",
    template = "class",
    legacy = "class",
    decl = "class",
    abstract = true,
    extends_slot = "class",
    implements = true,
    fields = "fields",
  },
  {
    label = "Interface",
    template = "interface",
    legacy = "interface",
    decl = "interface",
    extends_slot = "interface",
    fields = "methods",
  },
  {
    label = "Enum",
    template = "enum",
    legacy = "enum",
    decl = "enum",
    implements = true,
    fields = "fields",
    values = true,
  },
  {
    label = "Record",
    template = "record",
    legacy = "record",
    decl = "record",
    implements = true,
    fields = "components",
  },
  { label = "Annotation", template = "annotation", legacy = "annotation", decl = "annotation", fields = "elements" },

  -- templates adicionais do jc.nvim (só os que fazem sentido no Java puro ou
  -- com a dependência detectada no build)
  {
    label = "Exception",
    template = "exception",
    decl = "class",
    extends_slot = "class",
    implements = true,
    fields = "fields",
    extra = true,
  },
  {
    label = "Class with main",
    template = "main",
    decl = "class",
    extends_slot = "class",
    implements = true,
    fields = "fields",
    extra = true,
  },
  {
    label = "Singleton",
    template = "singleton",
    decl = "class",
    implements = true,
    fields = "fields",
    extra = true,
  },
  {
    label = "Serializable",
    template = "serializable",
    decl = "class",
    extends_slot = "class",
    implements = true,
    fields = "fields",
    extra = true,
  },
  {
    label = "JUnit 5 Test",
    template = "junit5",
    decl = "class",
    fields = "fields",
    requires = "junit",
    extra = true,
  },
  {
    label = "Spring Service",
    template = "service",
    decl = "class",
    implements = true,
    fields = "fields",
    requires = "spring",
    extra = true,
  },
  {
    label = "Spring Component",
    template = "component",
    decl = "class",
    implements = true,
    fields = "fields",
    requires = "spring",
    extra = true,
  },
  {
    label = "Spring Controller",
    template = "controller",
    decl = "class",
    implements = true,
    fields = "fields",
    requires = "spring",
    extra = true,
  },
  {
    label = "Spring Repository",
    template = "repository",
    decl = "interface",
    fields = "methods",
    requires = "jpa",
    extra = true,
  },
  {
    label = "JPA Entity",
    template = "entity",
    decl = "class",
    implements = true,
    fields = "fields",
    requires = "jpa",
    extra = true,
  },
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

local primitives = {
  boolean = true,
  byte = true,
  short = true,
  int = true,
  long = true,
  char = true,
  float = true,
  double = true,
}

---Valida uma expressão de tipo (primitivo, FQN, generics, arrays).
---Não tenta ser um parser completo: rejeita o que é claramente inválido.
---@param value string
---@param allow_void boolean|nil
---@return boolean
local function is_type(value, allow_void)
  if value == "" then
    return false
  end
  if value == "void" then
    return allow_void == true
  end
  if keywords[value] and not primitives[value] then
    return false
  end
  if not value:match("^[%w_$%.,%s%<%>%?%[%]&]+$") then
    return false
  end
  if value:match("%.%.") or value:match("^%.") or value:match("%.$") then
    return false
  end
  local depth = 0
  local brackets = 0
  for i = 1, #value do
    local c = value:sub(i, i)
    if c == "<" then
      depth = depth + 1
    elseif c == ">" then
      depth = depth - 1
      if depth < 0 then
        return false
      end
    elseif c == "[" then
      brackets = brackets + 1
    elseif c == "]" then
      brackets = brackets - 1
      if brackets < 0 then
        return false
      end
    end
  end
  return depth == 0 and brackets == 0
end

local function contains(list, value)
  for _, item in ipairs(list) do
    if item == value then
      return true
    end
  end
  return false
end

-- ---------- dependências do projeto ----------

---Texto (minúsculo) dos arquivos de build da raiz e dos módulos diretos.
---Usado para habilitar/desabilitar templates e decidir javax vs jakarta.
---@param root string
---@return string
local function build_text(root)
  local parts = {}
  for _, dir in ipairs(project.modules(root)) do
    for _, name in ipairs({ "pom.xml", "build.gradle", "build.gradle.kts" }) do
      local path = dir .. "/" .. name
      if vim.fn.filereadable(path) == 1 then
        parts[#parts + 1] = table.concat(vim.fn.readfile(path), "\n")
      end
    end
  end
  return table.concat(parts, "\n"):lower()
end

local function has_junit(deps)
  return deps:find("junit", 1, true) ~= nil
end

local function has_spring(deps)
  return deps:find("org.springframework", 1, true) ~= nil
    or deps:find("spring-boot", 1, true) ~= nil
    or deps:find("spring-context", 1, true) ~= nil
    or deps:find("spring-web", 1, true) ~= nil
end

local function has_jpa(deps)
  return deps:find("spring-boot-starter-data-jpa", 1, true) ~= nil
    or deps:find("spring-data-jpa", 1, true) ~= nil
    or deps:find("jakarta.persistence", 1, true) ~= nil
    or deps:find("javax.persistence", 1, true) ~= nil
    or deps:find("hibernate-core", 1, true) ~= nil
    or deps:find("eclipselink", 1, true) ~= nil
end

---Namespace de persistência do projeto ("jakarta" ou "javax").
---@param deps string
---@return string|nil
local function persistence_namespace(deps)
  if deps:find("jakarta", 1, true) then
    return "jakarta"
  end
  if deps:find("javax", 1, true) then
    return "javax"
  end
  -- spring-boot-starter-parent 3.x => jakarta, 2.x => javax
  local version = deps:match("spring%-boot%-starter%-parent.-<version>%s*([%d]+)")
  if version then
    return version == "3" and "jakarta" or "javax"
  end
  return nil
end

-- ---------- templates do jc.nvim ----------

---Templates públicos do jc.nvim (módulo de dados, não inicia servidor).
local function jc_templates()
  local ok, templates = pcall(require, "jc.templates")
  if ok and type(templates.render) == "function" then
    return templates
  end
end

local FIXED_IMPORTS = {
  service = { "org.springframework.stereotype.Service" },
  component = { "org.springframework.stereotype.Component" },
  controller = {
    "org.springframework.web.bind.annotation.RestController",
    "org.springframework.web.bind.annotation.RequestMapping",
  },
  repository = { "org.springframework.data.jpa.repository.JpaRepository" },
}

---Imports que o template não declara sozinho (as anotações do jc são
---resolvidas por organize-imports no fluxo original; aqui declaramos o
---namespace detectado para nunca gerar import ambíguo).
---@param kind JavaKind
---@param deps string
---@return string[]|nil
local function template_imports(kind, deps)
  if kind.template == "entity" then
    local ns = persistence_namespace(deps or "")
    if not ns then
      return nil
    end
    return {
      ns .. ".persistence.Entity",
      ns .. ".persistence.Id",
      ns .. ".persistence.GeneratedValue",
      ns .. ".persistence.GenerationType",
      ns .. ".persistence.Column",
    }
  end
  return FIXED_IMPORTS[kind.template]
end

---@param kind JavaKind
---@param deps string
---@return boolean, string|nil
local function kind_availability(kind, deps)
  if kind.requires == "junit" and not has_junit(deps) then
    return false, "projeto sem dependência JUnit no pom/build.gradle"
  end
  if kind.requires == "spring" and not has_spring(deps) then
    return false, "projeto sem dependência Spring no pom/build.gradle"
  end
  if kind.requires == "jpa" then
    if not has_jpa(deps) then
      return false, "projeto sem JPA (spring-data-jpa / jakarta.persistence)"
    end
    if kind.template == "entity" and not persistence_namespace(deps) then
      return false, "não consegui decidir jakarta.persistence vs javax.persistence"
    end
  end
  if kind.extra then
    local templates = jc_templates()
    if not templates then
      return false, "jc.nvim não está carregado"
    end
    if type(templates.get) ~= "function" or templates.get(kind.template) == nil then
      return false, "template '" .. kind.template .. "' não existe neste jc.nvim"
    end
  end
  return true
end

---@return boolean
local function jdtls_attached()
  return #vim.lsp.get_clients({ name = "jdtls" }) > 0
end

---Renderiza o tipo com o template do jc.nvim.
---@param kind JavaKind
---@param pkg string
---@param name string
---@param opts table|nil
---@return string|nil
local function render_jc(kind, pkg, name, opts)
  local templates = jc_templates()
  if not templates then
    return nil
  end
  opts = vim.deepcopy(opts or {})
  opts.name = name
  opts.package = pkg
  local ok, body = pcall(templates.render, kind.template, opts)
  if not ok or type(body) ~= "string" or vim.trim(body) == "" then
    return nil
  end
  if kind.abstract then
    body = body:gsub("public class ", "public abstract class ", 1)
  end
  -- os templates do jc.nvim contam com um :normal! gg=G depois; sem parser Java
  -- normalizamos aqui para remover linhas em branco extras
  body = body:gsub("\n\n\n+", "\n\n")
  return body
end

---Cria o arquivo do tipo pedido. Nunca sobrescreve.
---@param kind JavaKind
---@param source_root string
---@param pkg string
---@param name string
---@param opts table|nil extends/implements/fields/values/imports
---@return string|nil file
function M.create(kind, source_root, pkg, name, opts)
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

  local body = render_jc(kind, pkg, name, opts)
  if body then
    -- :edit dispara BufNewFile, então o jc marca o arquivo como novo e
    -- atualiza o build path do jdtls no primeiro write
    vim.cmd.edit(vim.fn.fnameescape(file))
    vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(body:gsub("\n+$", ""), "\n", { plain = true }))
    vim.cmd.write()
    notify("criado " .. rel)
    return file
  end

  if kind.extra then
    notify("o template '" .. kind.template .. "' exige o jc.nvim carregado", vim.log.levels.ERROR)
    return nil
  end

  -- fallback: gerador anterior (apenas tipos básicos)
  local has_options = opts
    and (
      (opts.extends and opts.extends ~= "")
      or (opts.implements and opts.implements ~= "")
      or (opts.fields and #opts.fields > 0)
      or (opts.values and #opts.values > 0)
    )
  if has_options then
    notify("jc.nvim não está carregado — extends/implements/campos não serão aplicados", vim.log.levels.WARN)
  end
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

-- ---------- busca de tipos no JDTLS ----------

local TYPE_KINDS = {
  -- LSP SymbolKind: 5 class, 10 enum, 11 interface, 23 struct(record no jdtls)
  class = { [5] = true },
  interface = { [11] = true },
  all = { [5] = true, [10] = true, [11] = true, [23] = true },
}

---workspace/symbol no cliente jdtls atual; devolve FQNs importáveis.
---@param query string
---@param allowed table<number, boolean>
---@return string[]|nil
local function search_types(query, allowed)
  local client
  for _, c in ipairs(vim.lsp.get_clients({ name = "jdtls" })) do
    client = c
    break
  end
  if not client then
    return nil
  end

  local response
  local ok = pcall(function()
    if type(client.request_sync) == "function" then
      response = client:request_sync("workspace/symbol", { query = query }, 3000)
    else
      local results = vim.lsp.buf_request_sync(0, "workspace/symbol", { query = query }, 3000)
      for _, result in pairs(results or {}) do
        response = result
        break
      end
    end
  end)
  if not ok or type(response) ~= "table" or response.err then
    return nil
  end

  local result = response.result
  if type(result) ~= "table" then
    return nil
  end

  local out, seen = {}, {}
  local root = project.root()
  for _, sym in ipairs(result) do
    local uri = sym.location and sym.location.uri or ""
    -- tipos aninhados não são importáveis pelo nome simples (e aqui entram
    -- como FQN, mas o jdtls indexa $Inner: evita poluir a lista)
    local enclosing = sym.containerName and sym.containerName:match("[^.]+$")
    local nested = uri:find("%$") ~= nil or (enclosing ~= nil and enclosing:match("^%u") ~= nil)
    -- o índice é de todo o workspace: aceita tipos do projeto atual e das
    -- dependências no classpath (jdt://), ignorando outros projetos abertos
    local from_project = false
    if uri:match("^file:") and root then
      local path = vim.uri_to_fname(uri)
      from_project = path:sub(1, #root + 1) == root .. "/"
    end
    local importable = uri:match("^jdt:") ~= nil or from_project
    local container = sym.containerName or ""
    local fqn = container ~= "" and (container .. "." .. sym.name) or sym.name
    if allowed[sym.kind] and importable and not nested and not seen[fqn] then
      seen[fqn] = true
      out[#out + 1] = fqn
    end
  end
  table.sort(out)
  return out
end

---Pergunta um tipo (busca no JDTLS ou FQN manual).
---@param slot string rótulo ("Superclasse", "Interfaces"…)
---@param allowed table<number, boolean>
---@param multi boolean
---@param on_done fun(types: string[])
local function ask_type(slot, allowed, multi, on_done)
  local function manual()
    input({ prompt = slot .. " — FQN (ex.: java.util.ArrayList): " }, function(value)
      if value == nil then
        return
      end
      value = vim.trim(value)
      if not is_type(value, false) or (not multi and value:find(",", 1, true) ~= nil) then
        notify("tipo Java inválido: " .. (value == "" and "(vazio)" or value), vim.log.levels.WARN)
        return manual()
      end
      on_done({ value })
    end)
  end

  if not jdtls_attached() then
    notify("jdtls não está anexado — informe o tipo por FQN", vim.log.levels.WARN)
    return manual()
  end

  input({ prompt = slot .. " — buscar tipo no jdtls (vazio = digitar FQN): " }, function(query)
    if query == nil then
      return
    end
    query = vim.trim(query)
    if query == "" then
      return manual()
    end
    local found = search_types(query, allowed)
    if not found or #found == 0 then
      notify("nenhum tipo encontrado para '" .. query .. "' — informe o FQN", vim.log.levels.WARN)
      return manual()
    end
    if multi then
      ui.pick_many(found, "Java: " .. slot .. " (Space/Tab seleciona, Enter confirma)", function(chosen)
        if chosen == nil then
          return
        end
        on_done(chosen)
      end)
    else
      select(found, { prompt = "Java: " .. slot }, function(choice)
        if choice == nil then
          return
        end
        on_done({ choice })
      end)
    end
  end)
end

-- ---------- fluxo: opções ----------

local ask_options
local show_summary

local function ask_extends(state)
  local slot = state.kind.extends_slot
  ask_type("Superclasse", TYPE_KINDS[slot], false, function(chosen)
    if not chosen or #chosen == 0 then
      return
    end
    state.extends = chosen[1]
    ask_options(state)
  end)
end

local function ask_parents(state)
  ask_type("Interfaces pai", TYPE_KINDS.interface, true, function(chosen)
    if not chosen or #chosen == 0 then
      return ask_options(state)
    end
    for _, type_name in ipairs(chosen) do
      if type_name ~= state.name and not contains(state.parents, type_name) then
        state.parents[#state.parents + 1] = type_name
      end
    end
    ask_options(state)
  end)
end

local function ask_implements(state)
  ask_type("Interfaces", TYPE_KINDS.interface, true, function(chosen)
    if not chosen or #chosen == 0 then
      return ask_options(state)
    end
    for _, type_name in ipairs(chosen) do
      if type_name ~= state.name and not contains(state.implements, type_name) then
        state.implements[#state.implements + 1] = type_name
      end
    end
    ask_options(state)
  end)
end

local FIELD_MODIFIERS = {
  { label = "private", value = "private" },
  { label = "private static", value = "private static" },
  { label = "protected", value = "protected" },
  { label = "protected static", value = "protected static" },
  { label = "public", value = "public" },
  { label = "public static", value = "public static" },
  { label = "static", value = "static" },
}

local function choose_modifier(on_done)
  local labels = {}
  local by_label = {}
  for _, modifier in ipairs(FIELD_MODIFIERS) do
    labels[#labels + 1] = modifier.label
    by_label[modifier.label] = modifier.value
  end
  select(labels, { prompt = "Java: modificador do campo" }, function(choice)
    if choice == nil then
      return
    end
    on_done(by_label[choice] or "private")
  end)
end

local function ask_fields(state)
  local kind = state.kind
  local is_component = kind.fields == "components"
  local is_member = kind.fields == "methods" or kind.fields == "elements"

  local ask_one

  local more_prompt = is_component and "Java: componentes"
    or kind.fields == "methods" and "Java: métodos"
    or kind.fields == "elements" and "Java: elementos"
    or "Java: campos"

  local function ask_more()
    select({ "Adicionar outro", "Voltar às opções" }, { prompt = more_prompt }, function(choice)
      if choice == nil then
        return
      end
      if choice == "Adicionar outro" then
        return ask_one()
      end
      ask_options(state)
    end)
  end

  ask_one = function()
    local type_prompt = is_component and "Tipo do componente: "
      or is_member and "Tipo de retorno: "
      or "Tipo do campo (FQN ou primitivo): "
    input({ prompt = type_prompt }, function(type_text)
      if type_text == nil then
        return
      end
      type_text = vim.trim(type_text)
      if not is_type(type_text, kind.fields == "methods") then
        notify("tipo Java inválido: " .. (type_text == "" and "(vazio)" or type_text), vim.log.levels.WARN)
        return ask_one()
      end

      local name_prompt = is_component and "Nome do componente: "
        or kind.fields == "methods" and "Nome do método: "
        or kind.fields == "elements" and "Nome do elemento: "
        or "Nome do campo: "
      input({ prompt = name_prompt }, function(field_name)
        if field_name == nil then
          return
        end
        field_name = vim.trim(field_name)
        if not is_identifier(field_name) then
          notify(
            "identificador Java inválido: " .. (field_name == "" and "(vazio)" or field_name),
            vim.log.levels.WARN
          )
          return ask_one()
        end
        for _, existing in ipairs(state.fields) do
          if existing.name == field_name then
            notify("já existe um campo/componente com esse nome: " .. field_name, vim.log.levels.WARN)
            return ask_one()
          end
        end

        if is_component or is_member then
          state.fields[#state.fields + 1] = { type = type_text, name = field_name, mod = "private" }
          return ask_more()
        end

        choose_modifier(function(mod)
          if mod == nil then
            return
          end
          state.fields[#state.fields + 1] = { type = type_text, name = field_name, mod = mod }
          ask_more()
        end)
      end)
    end)
  end

  ask_one()
end

local function ask_values(state)
  input({ prompt = "Constante do enum (vazio = terminar): ", default = "" }, function(value)
    if value == nil then
      return
    end
    value = vim.trim(value)
    if value == "" then
      return ask_options(state)
    end
    if not is_identifier(value) then
      notify("identificador Java inválido: " .. value, vim.log.levels.WARN)
      return ask_values(state)
    end
    if contains(state.values, value) then
      notify("constante duplicada: " .. value, vim.log.levels.WARN)
      return ask_values(state)
    end
    state.values[#state.values + 1] = value
    ask_values(state)
  end)
end

---@param state table
local function field_label(kind)
  if kind.fields == "components" then
    return "Componentes do record"
  elseif kind.fields == "methods" then
    return "Métodos"
  elseif kind.fields == "elements" then
    return "Elementos da anotação"
  end
  return "Campos"
end

ask_options = function(state)
  local kind = state.kind
  local items = { "(revisar e criar)" }
  local handlers = {}

  local function add(label, fn)
    items[#items + 1] = label
    handlers[label] = fn
  end

  if kind.extends_slot == "class" then
    add("Superclasse (extends)" .. (state.extends and (": " .. state.extends) or ""), function()
      ask_extends(state)
    end)
  elseif kind.extends_slot == "interface" then
    local suffix = #state.parents > 0 and (": " .. table.concat(state.parents, ", ")) or ""
    add("Interfaces pai (extends)" .. suffix, function()
      ask_parents(state)
    end)
  end

  if kind.implements then
    local suffix = #state.implements > 0 and (" (" .. #state.implements .. ")") or ""
    add("Interfaces (implements)" .. suffix, function()
      ask_implements(state)
    end)
  end

  if kind.fields then
    local suffix = #state.fields > 0 and (" (" .. #state.fields .. ")") or ""
    add(field_label(kind) .. suffix, function()
      ask_fields(state)
    end)
  end

  if kind.values then
    local suffix = #state.values > 0 and (" (" .. #state.values .. ")") or ""
    add("Constantes do enum" .. suffix, function()
      ask_values(state)
    end)
  end

  select(items, { prompt = "Java: opções (opcional)" }, function(choice)
    if choice == nil then
      return -- cancelado: nada foi criado
    end
    if choice == "(revisar e criar)" then
      return show_summary(state)
    end
    local handler = handlers[choice]
    if handler then
      handler()
    end
  end)
end

-- ---------- resumo e criação ----------

local function file_path(source_root, pkg, name)
  local dir = source_root
  if pkg ~= "" then
    dir = dir .. "/" .. pkg:gsub("%.", "/")
  end
  return dir .. "/" .. name .. ".java"
end

---Interfaces implementadas, incluindo o padrão do template (deduplicado:
---o template serializable já declara Serializable).
---@param state table
---@return string[]
local function effective_implements(state)
  local out = {}
  local implicit_serializable = state.kind.template == "serializable"
  if implicit_serializable then
    out[#out + 1] = "Serializable"
  end
  for _, type_name in ipairs(state.implements) do
    local redundant = implicit_serializable
      and (type_name == "Serializable" or type_name:match("%.Serializable$") ~= nil)
    if not redundant then
      out[#out + 1] = type_name
    end
  end
  return out
end

---@param state table
---@return table opts
local function build_opts(state)
  local opts = { imports = template_imports(state.kind, state.deps) }
  local interfaces = {}

  if state.kind.extends_slot == "interface" then
    for _, type_name in ipairs(state.parents) do
      interfaces[#interfaces + 1] = type_name
    end
    if #interfaces > 0 then
      opts.extends = table.concat(interfaces, ", ")
    end
  else
    if state.extends then
      opts.extends = state.extends
    end
    local effective = effective_implements(state)
    if #effective > 0 then
      opts.implements = table.concat(effective, ", ")
    end
  end

  if #state.fields > 0 then
    opts.fields = state.fields
  end
  if #state.values > 0 then
    opts.values = state.values
  end
  return opts
end

---@param state table
local function summary_lines(state)
  local kind = state.kind
  local root = project.root() or state.root
  local file = file_path(state.root, state.pkg, state.name)
  local rel = vim.fs.relpath(root, file) or file
  local lines = {
    "Tipo: " .. kind.label .. " (" .. kind.decl .. ")",
    "Nome: " .. state.name,
    "Package: " .. (state.pkg == "" and "(default)" or state.pkg),
    "Source root: " .. state.root,
    "Arquivo: " .. rel,
  }

  if vim.fn.filereadable(file) == 1 then
    lines[#lines + 1] = "AVISO: o arquivo já existe — nada será sobrescrito"
  end

  if state.extends then
    lines[#lines + 1] = "Extends: " .. state.extends
  elseif kind.template == "exception" then
    lines[#lines + 1] = "Extends: Exception (padrão do template)"
  end
  if state.kind.extends_slot == "interface" and #state.parents > 0 then
    lines[#lines + 1] = "Extends: " .. table.concat(state.parents, ", ")
  elseif kind.template == "repository" then
    local entity = state.name:gsub("Repository$", ""):gsub("Repo$", "")
    if entity == "" then
      entity = "Entity"
    end
    lines[#lines + 1] = "Extends: JpaRepository<" .. entity .. ", Long> (padrão do template)"
  end
  local implemented = effective_implements(state)
  if #implemented > 0 then
    lines[#lines + 1] = "Implements: " .. table.concat(implemented, ", ")
  end

  local opts = build_opts(state)
  if opts.imports and #opts.imports > 0 then
    lines[#lines + 1] = "Imports: " .. table.concat(opts.imports, ", ")
  end

  if #state.fields > 0 then
    if kind.fields == "components" then
      local parts = {}
      for _, field in ipairs(state.fields) do
        parts[#parts + 1] = field.type .. " " .. field.name
      end
      lines[#lines + 1] = "Componentes: " .. table.concat(parts, ", ")
    elseif kind.fields == "methods" or kind.fields == "elements" then
      local parts = {}
      for _, field in ipairs(state.fields) do
        parts[#parts + 1] = field.type .. " " .. field.name .. "();"
      end
      lines[#lines + 1] = (kind.fields == "methods" and "Métodos: " or "Elementos: ") .. table.concat(parts, " ")
    else
      local parts = {}
      for _, field in ipairs(state.fields) do
        parts[#parts + 1] = field.mod .. " " .. field.type .. " " .. field.name .. ";"
      end
      lines[#lines + 1] = "Campos: " .. table.concat(parts, " ")
    end
  end

  if #state.values > 0 then
    lines[#lines + 1] = "Constantes: " .. table.concat(state.values, ", ")
  end

  return lines
end

---Mostra o resumo e só cria depois de "Criar".
---@param state table
show_summary = function(state)
  local lines = summary_lines(state)
  local items = { "Criar", "Cancelar" }
  vim.list_extend(items, lines)

  select(items, { prompt = "Java: resumo — Enter cria, Esc cancela" }, function(choice)
    if choice ~= "Criar" then
      return -- cancelado
    end
    M.create(state.kind, state.root, state.pkg, state.name, build_opts(state))
  end)
end

M._summary = show_summary

-- ---------- entradas ----------

---Pergunta package (com sugestão) e nome, depois abre as opções.
---@param kind JavaKind
---@param source_root string
---@param suggested_pkg string
---@param deps string
local function ask(kind, source_root, suggested_pkg, deps)
  input({ prompt = "Package (vazio = default): ", default = suggested_pkg }, function(pkg)
    if pkg == nil then
      return -- cancelado
    end
    pkg = vim.trim(pkg)
    if not is_package(pkg) then
      notify("package Java inválido: " .. pkg, vim.log.levels.WARN)
      return ask(kind, source_root, suggested_pkg, deps)
    end

    input({ prompt = "Nome do tipo: " }, function(name)
      if name == nil then
        return -- cancelado
      end
      name = vim.trim(name)
      if not is_identifier(name) then
        notify("identificador Java inválido: " .. (name == "" and "(vazio)" or name), vim.log.levels.WARN)
        return ask(kind, source_root, pkg, deps)
      end

      ask_options({
        kind = kind,
        root = source_root,
        pkg = pkg,
        name = name,
        deps = deps,
        extends = nil,
        parents = {},
        implements = {},
        fields = {},
        values = {},
      })
    end)
  end)
end

---Escolha do source root (com opção de digitar outro).
---@param kind JavaKind
---@param roots table[]
---@param deps string
local function pick_root(kind, roots, deps)
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
        ask(kind, path, project.package_for(0, path), deps)
      end)
      return
    end
    for _, r in ipairs(ordered) do
      if r.label == choice then
        return ask(kind, r.path, project.package_for(0, r.path), deps)
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

  local deps = build_text(root)

  local labels = {}
  local by_label = {}
  for _, kind in ipairs(M.kinds) do
    local available, reason = kind_availability(kind, deps)
    local label = kind.label
    if not available then
      label = label .. "  (indisponível: " .. reason .. ")"
    end
    labels[#labels + 1] = label
    by_label[label] = { kind = kind, available = available, reason = reason }
  end

  select(labels, { prompt = "Java: New" }, function(label)
    if label == nil then
      return -- cancelado
    end
    local entry = by_label[label]
    if not entry then
      return
    end
    if not entry.available then
      notify(entry.reason, vim.log.levels.WARN)
      return
    end
    pick_root(entry.kind, roots, deps)
  end)
end

return M

-- java_menu/tests.lua
-- <leader>jt: testes JUnit via neotest + adaptador do jc.nvim.
-- Nada de runner próprio: as operações delegam para as APIs públicas do jc
-- (jc.test.*) e do neotest; o classpath/JDK continuam vindo do jdtls.

local ui = require("java_menu.ui")
local project = require("java_menu.project")
local lsp = require("java_menu.lsp")

local M = {}

local function neotest()
  local ok, nt = pcall(require, "neotest")
  if ok then
    return nt
  end
end

local function jc_test()
  local ok, mod = pcall(require, "jc.test")
  if ok then
    return mod
  end
end

---FQN aproximado de um arquivo de teste (src/test/java/<pkg>/X.java).
local function test_fqn(path)
  return path:gsub(".*[/\\]src[/\\]test[/\\]java[/\\]", ""):gsub("%.java$", ""):gsub("[/\\]", ".")
end

---Arquivos de teste do projeto (src/test/java), com FQN aproximado.
local function test_files(root)
  local files = vim.fn.glob(root .. "/**/src/test/java/**/*.java", true, true)
  local out = {}
  for _, path in ipairs(files) do
    out[#out + 1] = { label = test_fqn(path), path = path }
  end
  table.sort(out, function(a, b)
    return a.label < b.label
  end)
  return out
end

---Roda um arquivo de teste pelo neotest usando o adaptador do jc.
local function run_file(path)
  local nt = neotest()
  if not nt then
    ui.notify("neotest não está disponível", vim.log.levels.ERROR)
    return
  end
  local ok_target, target = pcall(require, "jc.neotest.target")
  local args = ok_target and target.run_args(path, path) or path
  nt.run.run(args)
  pcall(function()
    nt.summary.open()
  end)
end

---Run Nearest; sem teste pareado, oferece os testes do package via Snacks
---(o fallback interno do jc usava vim.ui.select).
local function run_nearest()
  local jc = jc_test()
  local path = vim.fn.expand("%:p")
  local ok_cg, cg = pcall(require, "jc.class_generator")

  local counterpart
  if ok_cg and type(cg.test_counterpart) == "function" then
    local ok, result = pcall(cg.test_counterpart, path)
    counterpart = ok and result or nil
  end

  if counterpart and vim.fn.filereadable(counterpart) == 0 and jc then
    local production = type(jc._nothing_to_run) == "function" and jc._nothing_to_run(path)
    local package_tests = type(jc._package_tests) == "function" and jc._package_tests(path) or {}
    if production and #package_tests > 0 then
      local labels, by_label = {}, {}
      for _, file in ipairs(package_tests) do
        local label = test_fqn(file)
        labels[#labels + 1] = label
        by_label[label] = file
      end
      ui.pick_one(labels, "Java: Tests — sem teste pareado (rodar do package)", function(choice)
        local file = by_label[choice]
        if file then
          run_file(file)
        end
      end)
      return
    end
  end

  if jc and type(jc.run_at_cursor) == "function" then
    jc.run_at_cursor()
  end
end

local function pick_test(root)
  local items = test_files(root)
  if #items == 0 then
    ui.notify("nenhuma classe de teste em src/test/java", vim.log.levels.WARN)
    return
  end

  local labels, by_label = {}, {}
  for _, item in ipairs(items) do
    labels[#labels + 1] = item.label
    by_label[item.label] = item
  end

  ui.pick_one(labels, "Java: Tests — rodar teste", function(choice)
    local item = by_label[choice]
    if item then
      run_file(item.path)
    end
  end)
end

---Entrada do `<leader>jt`.
function M.tests()
  local bufnr = vim.api.nvim_get_current_buf()
  local root = project.root(bufnr)
  if not root then
    ui.notify("nenhum projeto Maven/Gradle (pom.xml, build.gradle) a partir deste buffer", vim.log.levels.WARN)
    return
  end

  local nt = neotest()
  local jc = jc_test()
  local attached = ui.jdtls_attached(bufnr)
  local is_java = vim.bo[bufnr].filetype == "java"
  local multimodule = #project.modules(root) > 1

  if is_java and vim.bo[bufnr].modified then
    ui.notify(
      "este buffer tem alterações não salvas: a descoberta de testes lê o arquivo do disco, então nomes/novos testes podem não aparecer até salvar",
      vim.log.levels.WARN
    )
  end

  local no_neotest = "neotest não instalado"
  local no_jdtls = "jdtls não está anexado (classpath de teste vem do jdtls)"
  local no_jc = "jc.nvim não está carregado"

  local function run_reason()
    if not nt then
      return no_neotest
    end
    if not jc then
      return no_jc
    end
    if not attached then
      return no_jdtls
    end
  end

  local precompile = false
  local ok_jc, jc_mod = pcall(require, "jc")
  if ok_jc and jc_mod.config and jc_mod.config.test then
    precompile = jc_mod.config.test.precompile == true
  end

  local goto_test_available = false
  do
    local ok, cg = pcall(require, "jc.class_generator")
    goto_test_available = ok and type(cg.goto_test) == "function"
  end

  local run_enabled = run_reason() == nil

  local entries = {
    {
      key = "nearest",
      label = "Run Nearest Test",
      enabled = run_enabled and is_java,
      reason = run_reason() or "abra um arquivo .java de teste",
    },
    {
      key = "file",
      label = "Run Test File",
      enabled = run_enabled and is_java,
      reason = run_reason() or "abra um arquivo .java",
    },
    {
      key = "suite",
      label = "Run Test Suite" .. (multimodule and "  (multimódulo: enraíza no módulo atual)" or ""),
      enabled = run_enabled,
      reason = run_reason(),
    },
    {
      key = "pick",
      label = "Pick Test…",
      enabled = run_enabled,
      reason = run_reason(),
    },
    {
      key = "last",
      label = "Repeat Last Test",
      enabled = run_enabled,
      reason = run_reason(),
    },
    {
      key = "stop",
      label = "Stop Running Test",
      enabled = nt ~= nil,
      reason = no_neotest,
    },
    {
      key = "summary",
      label = "Show Test Summary",
      enabled = nt ~= nil,
      reason = no_neotest,
    },
    {
      key = "output",
      label = "Show Test Output",
      enabled = nt ~= nil,
      reason = no_neotest,
    },
    {
      key = "precompile",
      label = "Toggle Precompile (atual: " .. (precompile and "ON — maven/gradle" or "OFF — só jdtls") .. ")",
      enabled = jc ~= nil,
      reason = no_jc,
    },
    {
      key = "goto_test",
      label = "Go to Test",
      enabled = goto_test_available and is_java,
      reason = (not goto_test_available and "API do jc indisponível") or "abra um arquivo .java",
    },
  }

  ui.menu(entries, "Java: Tests", function(entry)
    -- runs usam classpath/commands do jc/neotest, que resolvem o cliente
    -- globalmente; stop/summary/output/goto_test não iniciam request no cliente
    local run_keys = { nearest = true, file = true, suite = true, pick = true, last = true }
    if run_keys[entry.key] then
      local jc_guard = lsp.jc_global_reason("Tests")
      if jc_guard then
        ui.notify(jc_guard, vim.log.levels.WARN)
        return
      end
    end
    if entry.key == "nearest" then
      run_nearest()
    elseif entry.key == "file" then
      jc.run_file()
    elseif entry.key == "suite" then
      if multimodule then
        ui.notify(
          "suite em multimódulo: o jc/neotest enraíza no módulo atual — use Pick Test ou Run Test File para os outros módulos",
          vim.log.levels.WARN
        )
      end
      jc.run_all()
    elseif entry.key == "pick" then
      pick_test(root)
    elseif entry.key == "last" then
      jc.run_last()
    elseif entry.key == "stop" then
      jc.stop()
    elseif entry.key == "summary" then
      jc.summary()
    elseif entry.key == "output" then
      jc.output()
    elseif entry.key == "precompile" then
      jc.toggle_precompile()
    elseif entry.key == "goto_test" then
      require("jc.class_generator").goto_test()
    end
  end)
end

-- expostos para testes
M._test_files = test_files
M._run_file = run_file

return M

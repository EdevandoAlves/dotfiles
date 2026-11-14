-- java_menu/debug.lua
-- <leader>jd: debug Java via nvim-dap + java-debug (jdtls).
-- Não cria adaptador nem UI própria: registra apenas o adaptador do nvim-jdtls
-- (feito em plugins/java.lua) e reutiliza nvim-dap / nvim-dap-ui.

local ui = require("java_menu.ui")

local M = {}

local function dap()
  local ok, mod = pcall(require, "dap")
  if ok then
    return mod
  end
end

local function dapui()
  local ok, mod = pcall(require, "dapui")
  if ok then
    return mod
  end
end

local function java_ready()
  local d = dap()
  return d ~= nil and d.adapters ~= nil and d.adapters.java ~= nil
end

local function session()
  local d = dap()
  return d and d.session() or nil
end

local function is_attach(sess)
  return sess ~= nil and sess.config ~= nil and sess.config.request == "attach"
end

local function launch_configs()
  local d = dap()
  local out = {}
  for _, config in ipairs((d and d.configurations and d.configurations.java) or {}) do
    if config.request == "launch" then
      out[#out + 1] = config
    end
  end
  return out
end

-- ---------- buffer de contexto ----------

local DEBUG_FILETYPES = {
  ["dap-repl"] = true,
  ["dapui_scopes"] = true,
  ["dapui_breakpoints"] = true,
  ["dapui_stacks"] = true,
  ["dapui_watches"] = true,
  ["dapui_console"] = true,
  ["dapui_hover"] = true,
}

local last_code_buf

---Buffer de código por trás do REPL/painéis do DAP (o menu pode ser aberto de lá).
local function context_buf()
  local cur = vim.api.nvim_get_current_buf()
  if not DEBUG_FILETYPES[vim.bo[cur].filetype] then
    if vim.bo[cur].buftype == "" then
      last_code_buf = cur
    end
    return cur
  end
  if last_code_buf and vim.api.nvim_buf_is_valid(last_code_buf) then
    return last_code_buf
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" and not DEBUG_FILETYPES[vim.bo[buf].filetype] then
      return buf
    end
  end
  return cur
end

-- ---------- operações ----------

local function debug_main()
  if session() then
    ui.notify("já existe uma sessão de debug ativa — encerre antes de iniciar outra", vim.log.levels.WARN)
    return
  end

  local configs = launch_configs()
  if #configs == 0 then
    ui.notify(
      "nenhuma main class descoberta pelo jdtls — abra um arquivo .java do projeto com o jdtls anexado e reabra o menu",
      vim.log.levels.WARN
    )
    return
  end

  local labels, by_label = {}, {}
  for _, config in ipairs(configs) do
    labels[#labels + 1] = config.name
    by_label[config.name] = config
  end

  ui.pick_one(labels, "Java: Debug — main class", function(choice)
    local config = by_label[choice]
    if not config then
      return
    end
    if session() then
      ui.notify("já existe uma sessão de debug ativa", vim.log.levels.WARN)
      return
    end
    dap().run(config)
  end)
end

local function debug_test(kind)
  if session() then
    ui.notify("já existe uma sessão de debug ativa — encerre antes de iniciar outra", vim.log.levels.WARN)
    return
  end
  local ok, jdtls_dap = pcall(require, "jdtls.dap")
  if not ok then
    ui.notify("jdtls.dap indisponível", vim.log.levels.ERROR)
    return
  end
  local fn = kind == "nearest" and jdtls_dap.test_nearest_method or jdtls_dap.test_class
  if type(fn) ~= "function" then
    ui.notify("debug de teste não suportado por esta versão do nvim-jdtls", vim.log.levels.WARN)
    return
  end
  pcall(fn, {})
end

local function attach_jvm()
  if session() then
    ui.notify("já existe uma sessão de debug ativa — encerre antes de anexar", vim.log.levels.WARN)
    return
  end

  ui.ask("Java: Debug — host JDWP: ", "127.0.0.1", function(host)
    if host == nil then
      return
    end
    host = vim.trim(host)
    if host == "" then
      host = "127.0.0.1"
    end
    ui.ask("Java: Debug — porta JDWP: ", "5005", function(port)
      if port == nil then
        return
      end
      local number = tonumber(vim.trim(port))
      if not number or number <= 0 or number > 65535 then
        ui.notify("porta inválida: " .. tostring(port), vim.log.levels.WARN)
        return
      end
      dap().run({
        type = "java",
        name = "Attach JVM " .. host .. ":" .. number,
        request = "attach",
        hostName = host,
        port = number,
      })
    end)
  end)
end

local function toggle_breakpoint(condition)
  if condition == nil then
    dap().toggle_breakpoint()
    return
  end
  ui.ask("Java: Debug — condição do breakpoint: ", "", function(value)
    if value == nil then
      return
    end
    value = vim.trim(value)
    if value == "" then
      dap().toggle_breakpoint()
    else
      dap().set_breakpoint(value)
    end
  end)
end

local function stop_session()
  local sess = session()
  if not sess then
    ui.notify("nenhuma sessão de debug ativa", vim.log.levels.WARN)
    return
  end
  if is_attach(sess) then
    -- JVM externa: apenas desconecta, nunca termina o processo
    dap().disconnect({ terminateDebuggee = false })
    ui.notify("desconectado da JVM (o processo externo continua rodando)", vim.log.levels.INFO)
    return
  end
  dap().terminate({})
end

local function float_elem(name)
  local ui_mod = dapui()
  if not ui_mod then
    ui.notify("nvim-dap-ui não está instalado", vim.log.levels.WARN)
    return
  end
  pcall(ui_mod.float_element, name)
end

-- ---------- menu ----------

---Entrada do `<leader>jd`.
function M.debug()
  local bufnr = context_buf()
  local sess = session()
  local ready = java_ready()
  local attached = ui.jdtls_attached(bufnr)
  local is_java = vim.bo[bufnr].filetype == "java"
  local has_ui = dapui() ~= nil

  local function session_reason()
    if not ready then
      return "java-debug não carregado (bundle não está no cliente jdtls — reinicie o Neovim)"
    end
    if not sess then
      return "nenhuma sessão de debug ativa"
    end
  end

  local function test_reason()
    if not ready then
      return "java-debug não carregado (reinicie o Neovim)"
    end
    if not attached then
      return "jdtls não está anexado (o debug de teste usa o java-test do jdtls)"
    end
    if not is_java then
      return "abra o arquivo .java do teste"
    end
  end

  local entries = {
    {
      key = "main",
      label = "Debug Main Class",
      enabled = ready and not sess and #launch_configs() > 0,
      reason = (not ready and "java-debug não carregado (reinicie o Neovim)")
        or (sess and "sessão de debug ativa")
        or "nenhuma main class descoberta pelo jdtls",
    },
    {
      key = "test_nearest",
      label = "Debug Nearest JUnit Test",
      enabled = ready and not sess and attached and is_java,
      reason = test_reason(),
    },
    {
      key = "test_class",
      label = "Debug JUnit Test Class",
      enabled = ready and not sess and attached and is_java,
      reason = test_reason(),
    },
    {
      key = "attach",
      label = "Attach JVM (JDWP, loopback)",
      enabled = ready and not sess,
      reason = (not ready and "java-debug não carregado (reinicie o Neovim)") or "sessão de debug ativa",
    },
    { key = "toggle_bp", label = "Toggle Breakpoint", enabled = true },
    { key = "cond_bp", label = "Conditional Breakpoint", enabled = true },
    {
      key = "continue",
      label = "Continue / Start",
      enabled = sess ~= nil,
      reason = session_reason(),
    },
    { key = "pause", label = "Pause", enabled = sess ~= nil, reason = session_reason() },
    { key = "over", label = "Step Over", enabled = sess ~= nil, reason = session_reason() },
    { key = "into", label = "Step Into", enabled = sess ~= nil, reason = session_reason() },
    { key = "out", label = "Step Out", enabled = sess ~= nil, reason = session_reason() },
    {
      key = "vars",
      label = "Inspect Variables",
      enabled = sess ~= nil and has_ui,
      reason = (sess == nil and session_reason()) or "nvim-dap-ui não instalado",
    },
    { key = "repl", label = "Open Debug REPL", enabled = sess ~= nil, reason = session_reason() },
    {
      key = "stack",
      label = "Show Call Stack",
      enabled = sess ~= nil and has_ui,
      reason = (sess == nil and session_reason()) or "nvim-dap-ui não instalado",
    },
    {
      key = "stop",
      label = (sess == nil) and "Stop Debug Session"
        or (is_attach(sess) and "Stop Debug Session (disconnect)" or "Stop Debug Session (terminate)"),
      enabled = sess ~= nil,
      reason = session_reason(),
    },
  }

  ui.menu(entries, "Java: Debug", function(entry)
    if entry.key == "main" then
      debug_main()
    elseif entry.key == "test_nearest" then
      debug_test("nearest")
    elseif entry.key == "test_class" then
      debug_test("class")
    elseif entry.key == "attach" then
      attach_jvm()
    elseif entry.key == "toggle_bp" then
      toggle_breakpoint(nil)
    elseif entry.key == "cond_bp" then
      toggle_breakpoint("")
    elseif entry.key == "continue" then
      dap().continue()
    elseif entry.key == "pause" then
      dap().pause()
    elseif entry.key == "over" then
      dap().step_over()
    elseif entry.key == "into" then
      dap().step_into()
    elseif entry.key == "out" then
      dap().step_out()
    elseif entry.key == "vars" then
      float_elem("scopes")
    elseif entry.key == "repl" then
      dap().repl.open()
    elseif entry.key == "stack" then
      float_elem("frames")
    elseif entry.key == "stop" then
      stop_session()
    end
  end)
end

-- expostos para testes
M._context_buf = context_buf
M._launch_configs = launch_configs

return M

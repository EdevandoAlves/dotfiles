-- Debugger C/C++ (codelldb instalado via Mason)
local function setup_codelldb()
  local ok, dap = pcall(require, "dap")
  if not ok then
    return
  end
  dap.adapters.codelldb = {
    type = "server",
    port = "${port}",
    executable = {
      command = vim.fn.stdpath("data") .. "/mason/bin/codelldb",
      args = { "--port", "${port}" },
    },
  }
  local c_configs = {
    {
      name = "Launch file",
      type = "codelldb",
      request = "launch",
      program = function()
        return vim.fn.input("Executável: ", vim.fn.getcwd() .. "/", "file")
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
    },
  }
  dap.configurations.c = c_configs
  dap.configurations.cpp = c_configs
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp" },
  callback = setup_codelldb,
})

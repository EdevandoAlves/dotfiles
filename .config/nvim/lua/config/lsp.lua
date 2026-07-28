-- config/lsp.lua (versão com debug)
local lspconfig = require("lspconfig")
local default_capabilities = vim.lsp.protocol.make_client_capabilities()

local servers = {
  ts_ls = {},
  html = {},
  cssls = {},
  intelephense = {
    settings = {
      intelephense = {
        files = {
          maxSize = 1000000,
        },
        format = {
          braces = "k&r",
        },
        diagnostics = {
          enable = true,
        },
      },
    },
    filetypes = { "php" },
    root_dir = function(fname)
      return lspconfig.util.root_pattern("composer.json", ".git")(fname) or lspconfig.util.path.dirname(fname)
    end,
  },
}

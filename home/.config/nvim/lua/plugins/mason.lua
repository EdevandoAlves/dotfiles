return {
  "mason-org/mason.nvim",
  dependencies = {
    "mason-org/mason.nvim",
  },
  config = function()
    require("mason").setup()
    require("mason-lspconfig").setup({
      ensure_installed = {
        "ts_ls",
        "cssls",
        "intelephense",
        "jdtls",
      },
      automatic_installation = true,
    })

    -- mason-lspconfig v2 removed setup_handlers; servers are now configured
    -- directly in lua/config/lsp.lua (which applies the per-server settings).
  end,
}

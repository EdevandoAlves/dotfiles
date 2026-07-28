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
      },
      automatic_installation = true,
    })

    require("mason-lspconfig").setup_handlers({
      function(server_name)
        require("lspconfig")[server_name].setup({})
      end,
    })
  end,
}

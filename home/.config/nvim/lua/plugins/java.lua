return {
  "mfussenegger/nvim-jdtls",
  dependencies = { "neovim/nvim-lspconfig" },
  config = function()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "java" },
      callback = function(ev)
        local root_dir = vim.fs.root(ev.file, {
          "pom.xml",
          "build.gradle",
          "build.gradle.kts",
          "settings.gradle",
          ".git",
        })
        if not root_dir then
          return
        end
        local project = vim.fn.fnamemodify(root_dir, ":t")
        local cmd = {
          vim.fn.stdpath("data") .. "/mason/bin/jdtls",
          "-data", vim.fn.stdpath("data") .. "/jdtls/" .. project,
        }
        require("jdtls").start_or_attach({
          cmd = cmd,
          root_dir = root_dir,
        })
      end,
    })
  end,
}

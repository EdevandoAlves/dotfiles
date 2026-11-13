return {
  -- jdtls: dono único do cliente LSP Java por projeto (root em pom/gradle)
  {
    "mfussenegger/nvim-jdtls",
    dependencies = { "neovim/nvim-lspconfig" },

    init = function()
      -- o jdtls é iniciado apenas pelo nvim-jdtls. O mason-lspconfig habilita
      -- o autostart do lspconfig (automatic_enable), que abriria um segundo
      -- cliente sem root_dir; sem filetypes, aquele autostart nunca casa.
      if vim.lsp and vim.lsp.config then
        pcall(vim.lsp.config, "jdtls", { filetypes = {} })
      end
    end,

    config = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "java",
        callback = function(ev)
          local file = ev.file ~= "" and ev.file or vim.api.nvim_buf_get_name(ev.buf)
          if file == "" then
            return
          end

          -- Projeto Maven/Gradle/git; se não houver marcador, cai para o
          -- diretório do arquivo para que arquivos soltos ainda tenham LSP.
          local root_dir = vim.fs.root(file, {
            "pom.xml",
            "build.gradle",
            "build.gradle.kts",
            "settings.gradle",
            "settings.gradle.kts",
            ".git",
          }) or vim.fs.dirname(file)

          local jdtls = vim.fn.exepath("jdtls")
          if jdtls == "" then
            jdtls = vim.fn.stdpath("data") .. "/mason/bin/jdtls"
          end

          local project = vim.fn.fnamemodify(root_dir, ":t")

          require("jdtls").start_or_attach({
            cmd = { jdtls, "-data", vim.fn.stdpath("data") .. "/jdtls/" .. project },
            root_dir = root_dir,
            capabilities = require("blink.cmp").get_lsp_capabilities(),
          })
        end,
      })
    end,
  },

  -- camada de produtividade Java sobre o jdtls acima (nunca inicia servidor)
  {
    "artur-shaik/jc.nvim",
    ft = { "java" },
    dependencies = { "mfussenegger/nvim-jdtls" },

    -- o menu não depende de FileType=java: a tecla carrega o plugin sob demanda
    keys = {
      {
        "<leader>jn",
        function()
          require("java_menu.new").new()
        end,
        desc = "New",
      },
      {
        "<leader>jg",
        function()
          require("java_menu.generate").generate()
        end,
        desc = "Generate",
      },
      {
        "<leader>jr",
        mode = { "n", "x" },
        function()
          require("java_menu.refactor").refactor()
        end,
        desc = "Refactor",
      },
      {
        "<leader>ji",
        function()
          require("java_menu.imports").imports()
        end,
        desc = "Imports",
      },
    },

    init = function()
      -- plugin/jc.vim faz autoload em FileType=java e chama setup() sem opts;
      -- desliga os mapas padrão antes disso para não sequestrar gf/<leader>j
      vim.g.jc_default_mappings = false
      vim.g.jc_autoformat_on_save = 0
    end,

    opts = {
      keys_prefix = "<leader>j",
      default_mappings = false,
      class_prompt = "wizard",
      map_gf = false,
      autoformat_on_save = false,
    },
  },

  -- grupos do menu Java no which-key v3
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>j", group = "java" },
      },
    },
  },
}

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
      local java_project = require("java_menu.project")
      local warned = {}

      -- bundles OSGi do java-debug/java-test (exclui runner-jar-with-dependencies
      -- e jacocoagent, que não são bundles)
      local bundles
      local function java_bundles()
        if bundles then
          return bundles
        end
        local mason = vim.env.MASON
        if not mason or mason == "" then
          mason = vim.fn.stdpath("data") .. "/mason"
        end
        bundles = {}
        for _, dir in ipairs({ mason .. "/share/java-debug-adapter", mason .. "/share/java-test" }) do
          for _, jar in ipairs(vim.fn.glob(dir .. "/*.jar", false, true)) do
            local name = vim.fs.basename(jar)
            if not name:find("runner%-jar%-with%-dependencies") and not name:find("jacocoagent") then
              bundles[#bundles + 1] = jar
            end
          end
        end
        return bundles
      end

      -- registra o adaptador DAP do jdtls e as configurações de main classes,
      -- uma vez por cliente (nvim-dap só é tocado aqui, para Java)
      local dap_ready = {}
      local function setup_java_dap(client)
        local root = client and client.config and client.config.root_dir or "?"
        if dap_ready[root] then
          return
        end
        dap_ready[root] = true
        local jdtls = require("jdtls")
        pcall(jdtls.setup_dap, {})
        local ok, dap = pcall(require, "jdtls.dap")
        if ok then
          pcall(dap.setup_dap_main_class_configs, {})
        end
      end

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          if client and client.name == "jdtls" then
            setup_java_dap(client)
          end
        end,
      })

      local function related(a, b)
        return a == b or (a:sub(1, #b + 1) == b .. "/") or (b:sub(1, #a + 1) == a .. "/")
      end

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "java",
        callback = function(ev)
          local file = ev.file ~= "" and ev.file or vim.api.nvim_buf_get_name(ev.buf)
          if file == "" then
            return
          end

          -- Agregador Maven/Gradle quando existir (project.lua sobe até o pai
          -- que declara o módulo); senão o marcador mais próximo; senão o
          -- diretório do arquivo, para arquivos soltos. `.git` não é marcador
          -- de projeto Java.
          local root_dir = java_project.root(ev.buf)
            or vim.fs.root(file, {
              "pom.xml",
              "build.gradle",
              "build.gradle.kts",
              "settings.gradle",
              "settings.gradle.kts",
            })
            or vim.fs.dirname(file)

          -- Um cliente por projeto: se já existe jdtls com outro root do mesmo
          -- projeto (sessão iniciada antes do agregador ser reconhecido), não
          -- abrimos um segundo cliente nem reiniciamos o servidor em silêncio.
          for _, client in ipairs(vim.lsp.get_clients({ name = "jdtls" })) do
            local other = client.config.root_dir
            if other and other ~= root_dir and related(other, root_dir) then
              if not warned[other] then
                warned[other] = true
                vim.notify(
                  ("jdtls já está ativo com root %s; para usar o workspace do agregador (%s) reinicie o Neovim"):format(
                    other,
                    root_dir
                  ),
                  vim.log.levels.WARN
                )
              end
              return
            end
          end

          local jdtls = vim.fn.exepath("jdtls")
          if jdtls == "" then
            jdtls = vim.fn.stdpath("data") .. "/mason/bin/jdtls"
          end

          local project = vim.fn.fnamemodify(root_dir, ":t")

          require("jdtls").start_or_attach({
            cmd = { jdtls, "-data", vim.fn.stdpath("data") .. "/jdtls/" .. project },
            root_dir = root_dir,
            capabilities = require("blink.cmp").get_lsp_capabilities(),
            init_options = { bundles = java_bundles() },
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
      {
        "<leader>jb",
        function()
          require("java_menu.build").build()
        end,
        desc = "Build/Run",
      },
      {
        "<leader>jt",
        function()
          require("java_menu.tests").tests()
        end,
        desc = "Tests",
      },
      {
        "<leader>jd",
        function()
          require("java_menu.debug").debug()
        end,
        desc = "Debug",
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

  -- testes: neotest com o adaptador do jc.nvim (nada de neotest-java)
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "artur-shaik/jc.nvim",
    },
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}
      table.insert(opts.adapters, require("jc").neotest_adapter())
      opts.consumers = opts.consumers or {}
      opts.consumers.jc = require("jc").neotest_consumer()
    end,
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

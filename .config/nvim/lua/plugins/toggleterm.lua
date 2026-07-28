return {
  {
    "akinsho/toggleterm.nvim",
    opts = {
      size = function(term)
        if term.direction == "horizontal" then
          local term_count = #require("toggleterm.terminal").get_all()
          local base_height = math.floor(vim.o.lines * 0.10) -- 5% da altura

          if term_count > 1 then
            return math.max(3, math.floor(vim.o.lines * 0.10 * term_count))
          end

          return math.max(3, base_height)
        end
      end,
      open_mapping = [[<c-/>]],
      shade_terminals = true,
      shading_factor = 2,
      start_in_insert = true,
      insert_mappings = true,
      terminal_mappings = true,
      persist_size = false,
      direction = "horizontal",
      close_on_exit = true,
      shell = vim.o.shell,
      auto_scroll = true,

      on_create = function(term)
        local all_terms = require("toggleterm.terminal").get_all()
        if #all_terms > 3 then
          vim.notify("Máximo de 3 terminais permitidos", vim.log.levels.WARN)
          term:close()
          return
        end
      end,

      on_open = function(term)
        local opts = { buffer = term.bufnr }
        vim.keymap.set("t", "<C-q>", "<cmd>close<cr>", opts)
        vim.keymap.set("n", "<C-q>", "<cmd>close<cr>", opts)

        vim.keymap.set("t", "<A-1>", "<cmd>1ToggleTerm<cr>", opts)
        vim.keymap.set("t", "<A-2>", "<cmd>2ToggleTerm<cr>", opts)
        vim.keymap.set("t", "<A-3>", "<cmd>3ToggleTerm<cr>", opts)
      end,
    },

    config = function(_, opts)
      require("toggleterm").setup(opts)

      vim.api.nvim_create_user_command("Term1", function()
        vim.cmd("1ToggleTerm")
      end, {})
      vim.api.nvim_create_user_command("Term2", function()
        vim.cmd("2ToggleTerm")
      end, {})
      vim.api.nvim_create_user_command("Term3", function()
        vim.cmd("3ToggleTerm")
      end, {})

      local map = vim.keymap.set

      map({ "n", "i", "t" }, "<C-\\>", "<cmd>1ToggleTerm<cr>", { desc = "Toggle Terminal 1" })

      map({ "n", "i" }, "<A-1>", "<cmd>1ToggleTerm<cr>", { desc = "Terminal 1" })
      map({ "n", "i" }, "<A-2>", "<cmd>2ToggleTerm<cr>", { desc = "Terminal 2" })
      map({ "n", "i" }, "<A-3>", "<cmd>3ToggleTerm<cr>", { desc = "Terminal 3" })

      map({ "n", "i" }, "<C-A-t>", function()
        local terms = require("toggleterm.terminal").get_all()
        local next_id = #terms + 1
        if next_id <= 3 then
          vim.cmd(next_id .. "ToggleTerm")
        else
          vim.notify("Máximo de 3 terminais atingido", vim.log.levels.WARN)
        end
      end, { desc = "Novo Terminal" })
    end,
  },
}

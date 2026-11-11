-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
local function map(mode, lhs, rhs, opts)
  local keys = require("lazy.core.handler").handlers.keys
  ---@cast keys LazyKeysHandler
  -- do not create the keymap if a lazy keys handler exists
  if not keys.active[keys.parse({ lhs, mode = mode }).id] then
    opts = opts or {}
    opts.silent = opts.silent ~= false
    if opts.remap and not vim.g.vscode then
      opts.remap = nil
    end
    vim.keymap.set(mode, lhs, rhs, opts)
  end
end

-- better up/down
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true, silent = true })
map({ "n", "x" }, "<Down>", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true, silent = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { desc = "Up", expr = true, silent = true })
map({ "n", "x" }, "<Up>", "v:count == 0 ? 'gk' : 'k'", { desc = "Up", expr = true, silent = true })

-- Move to window using the <ctrl> hjkl keys
map("n", "<C-h>", "<C-w>h", { desc = "Go to Left Window", remap = true })
map("n", "<C-j>", "<C-w>j", { desc = "Go to Lower Window", remap = true })
map("n", "<C-k>", "<C-w>k", { desc = "Go to Upper Window", remap = true })
map("n", "<C-l>", "<C-w>l", { desc = "Go to Right Window", remap = true })

-- Move Lines
map("n", "<A-Down>", "<cmd>execute 'move .+' . v:count1<cr>==", { desc = "Move Down" })
map("n", "<A-Up>",   "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = "Move Up" })
map("i", "<A-Down>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move Down" })
map("i", "<A-Up>",   "<esc><cmd>m .-2<cr>==gi", { desc = "Move Up" })
map("v", "<A-Down>", ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = "Move Down" })
map("v", "<A-Up>",   ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = "Move Up" })


-- Buffers
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next Buffer" })
map("n", "[b", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
map("n", "]b", "<cmd>bnext<cr>", { desc = "Next Buffer" })
map("n", "<leader>bb", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })
map("n", "<leader>`", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })
map("n", "<leader>bd", function()
  Snacks.bufdelete()
end, { desc = "Delete Buffer" })
map("n", "<leader>bo", function()
  Snacks.bufdelete.other()
end, { desc = "Delete Other Buffers" })
map("n", "<leader>bD", "<cmd>:bd<cr>", { desc = "Delete Buffer and Window" })

-- Telescope
map("n", "<C-p>", "<cmd>Telescope find_files<cr>", { desc = "Telescope Find Files" })
map("n", "<leader>fG", "<cmd>Telescope live_grep<cr>", { desc = "Telescope Live Grep" })
map("n", "<leader>fB", "<cmd>Telescope buffers<cr>", { desc = "Telescope Buffers" })

-- Harpoon
local harpoon = require("harpoon")
harpoon:setup()

map("n", "<leader>a", function()
  harpoon:list():add()
end, { desc = "Harpoon Add" })
map("n", "<leader>A", function()
  harpoon:list():clear()
end, { desc = "Harpoon Clear" })
map("n", "<C-e>", function()
  harpoon.ui:toggle_quick_menu(harpoon:list())
end)
map("n", "<S-p>", function()
  harpoon:list():prev()
end)
map("n", "<S-n>", function()
  harpoon:list():next()
end)

-- LSP
map("n", "K", vim.lsp.buf.hover)
map("n", "gd", vim.lsp.buf.definition)
map("n", "gr", vim.lsp.buf.references)
map("n", "<leader>rn", vim.lsp.buf.rename)
map("n", "<leader>ca", vim.lsp.buf.code_action)

-- DAP (Debugging)
map("n", "<leader>db", function() require("dap").toggle_breakpoint() end, { desc = "Toggle Breakpoint" })
map("n", "<leader>dc", function() require("dap").continue() end, { desc = "Continue" })
map("n", "<leader>di", function() require("dap").step_into() end, { desc = "Step Into" })
map("n", "<leader>do", function() require("dap").step_over() end, { desc = "Step Over" })
map("n", "<leader>dO", function() require("dap").step_out() end, { desc = "Step Out" })
map("n", "<leader>dr", function() require("dap").repl.toggle() end, { desc = "Toggle REPL" })
map("n", "<leader>dl", function() require("dap").run_last() end, { desc = "Run Last" })
map("n", "<leader>du", function() require("dapui").toggle() end, { desc = "Toggle DAP UI" })
map("n", "<leader>dx", function() require("dap").terminate() end, { desc = "Terminate Debug Session" })

-- Comments
-- NORMAL mode
map("n", "gcc", function() require("Comment.api").toggle.linewise.current() end, { desc = "Toggle Linewise Comment" })
map("n", "gbc", function() require("Comment.api").toggle.blockwise.current() end, { desc = "Toggle Blockwise Comment" })

-- VISUAL mode
map("x", "gc", "<esc><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<cr>", { desc = "Toggle Linewise Comment (Visual)" })
map("x", "gb", "<esc><cmd>lua require('Comment.api').toggle.blockwise(vim.fn.visualmode())<cr>", { desc = "Toggle Blockwise Comment (Visual)" })
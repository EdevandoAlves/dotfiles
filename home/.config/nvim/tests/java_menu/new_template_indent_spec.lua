-- Regression: New must run the same gg=G normalization jc uses for templates,
-- otherwise JUnit bodies are written flush-left.
-- Run with:
--   nvim --headless -u NONE \
--     -c "set rtp+=~/.config/nvim" \
--     -c "set rtp+=~/.local/share/nvim/lazy/jc.nvim" \
--     -c "luafile tests/java_menu/new_template_indent_spec.lua" -c qa

local ok_templates, templates = pcall(require, "jc.templates")
if not ok_templates or type(templates.render) ~= "function" then
  print("new_template_indent_spec: SKIP (jc.templates unavailable)")
  vim.cmd("qa!")
  return
end

local new = require("java_menu.new")
local kind
for _, candidate in ipairs(new.kinds) do
  if candidate.template == "junit5" then
    kind = candidate
  end
end
assert(kind, "template junit5 não encontrado em new.kinds")

local root = vim.fn.tempname() .. "/src/main/java"
vim.fn.mkdir(root, "p")
local file = new.create(kind, root, "spec", "IndentedTest", { imports = {} })
assert(file, "New não criou o arquivo")
local text = table.concat(vim.fn.readfile(file), "\n")
assert(text:find("\n[ \t]+@BeforeEach"), "corpo do template sem indentação:\n" .. text)
assert(text:find("\n[ \t]+void test%(%)"), "método do template sem indentação:\n" .. text)

vim.fn.delete(root, "rf")
print("new_template_indent_spec: OK")
vim.cmd("qa!")

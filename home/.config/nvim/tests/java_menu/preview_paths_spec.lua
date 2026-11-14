-- Regressão: limites reais de diretório no preview e buffer modificado no
-- destino de RenameFile.
--
-- Run:
--   nvim --headless -u NONE \
--     -c "set rtp+=~/.config/nvim" \
--     -c "luafile tests/java_menu/preview_paths_spec.lua" -c qa

local preview = require("java_menu.preview")
local root_dir = vim.fn.tempname() .. "/java-menu-preview-spec"
local other_root = root_dir .. "2"

vim.fn.mkdir(root_dir .. "/src", "p")
vim.fn.mkdir(other_root .. "/src", "p")
vim.fn.writefile({ "old" }, root_dir .. "/src/Main.java")
vim.fn.writefile({ "outside" }, other_root .. "/src/Main.java")

-- symlink do root para o mesmo projeto continua válido
local linked_root = root_dir .. "-link"
os.remove(linked_root)
assert(vim.uv.fs_symlink(root_dir, linked_root), "não consegui criar symlink do root")

-- symlink dentro do projeto apontando para fora continua inválido
os.remove(root_dir .. "/src/outside.txt")
assert(vim.uv.fs_symlink(other_root .. "/src/Main.java", root_dir .. "/src/outside.txt"))

assert(preview._inside_project(root_dir, root_dir .. "/src/Main.java"), "caminho válido rejeitado")
assert(not preview._inside_project(root_dir, other_root .. "/src/Main.java"), "irmão do root aceito")
assert(not preview._inside_project(root_dir, root_dir .. "2/src/Main.java"), "sufixo de root aceito")
assert(preview._inside_project(linked_root, linked_root .. "/src/Main.java"), "root via symlink rejeitado")
assert(not preview._inside_project(root_dir, root_dir .. "/src/outside.txt"), "symlink para fora aceito")

-- buffer modificado no destino, mesmo sem arquivo em disco
local old_path = root_dir .. "/src/Main.java"
local new_path = root_dir .. "/src/Renamed.java"
local stale_buf = vim.fn.bufadd(new_path)
vim.api.nvim_buf_set_lines(stale_buf, 0, -1, false, { "trabalho não salvo" })
assert(vim.bo[stale_buf].modified, "buffer de teste não ficou modificado")
assert(preview._modified_buffer_for(new_path) == stale_buf, "buffer modificado não encontrado")

local plan = {
  root = root_dir,
  encoding = "utf-16",
  ops = { { kind = "rename", old_path = old_path, new_path = new_path } },
  files = {},
}
local problems = preview._revalidate(plan)
local has_modified_problem = false
for _, problem in ipairs(problems) do
  if problem:find("buffer modificado não salvo", 1, true) then
    has_modified_problem = true
  end
end
assert(has_modified_problem, "revalidate não bloqueou buffer modificado: " .. vim.inspect(problems))

-- sem buffer modificado, a validação não reporta esse problema
vim.bo[stale_buf].modified = false
problems = preview._revalidate(plan)
for _, problem in ipairs(problems) do
  assert(not problem:find("buffer modificado não salvo", 1, true), "problema fantasma de buffer modificado")
end

-- cancelamento não aplica nada
local applied = false
local original_menu = require("java_menu.ui").menu
require("java_menu.ui").menu = function(_, _, on_choice)
  on_choice({ key = "cancel" })
end
local done = false
preview.review(plan, function(value)
  applied = value
  done = true
end)
require("java_menu.ui").menu = original_menu
assert(done and not applied, "cancelamento alterou o estado do preview")
assert(table.concat(vim.fn.readfile(old_path), "\n") == "old", "cancelamento alterou o arquivo de origem")
assert(vim.fn.filereadable(new_path) == 0, "cancelamento criou o destino")

print("preview_paths_spec: OK")
vim.cmd("qa!")

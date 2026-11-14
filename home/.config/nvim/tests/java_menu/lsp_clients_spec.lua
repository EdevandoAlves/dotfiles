-- Integração: dois projetos Java independentes com clientes JDTLS reais.
-- O helper do Java Menu deve escolher o cliente do buffer; o jc.nvim ainda
-- resolve o cliente globalmente, então operações internas devem ser bloqueadas
-- quando houver mais de um cliente.
--
-- Run:
--   nvim --headless -u NONE \
--     -c "set rtp+=~/.config/nvim" \
--     -c "set rtp+=~/.local/share/nvim/lazy/nvim-jdtls" \
--     -c "set rtp+=~/.local/share/nvim/lazy/nvim-lspconfig" \
--     -c "set rtp+=~/.local/share/nvim/lazy/jc.nvim" \
--     -c "luafile tests/java_menu/lsp_clients_spec.lua" -c qa

local lsp = require("java_menu.lsp")
local fixtures = require("tests.java_menu.fixtures")

local ok_jdtls, jdtls = pcall(require, "jdtls")
assert(ok_jdtls and type(jdtls.start_or_attach) == "function", "nvim-jdtls indisponível")

local jdtls_bin = vim.fn.exepath("jdtls")
if jdtls_bin == "" then
  local mason = vim.fn.stdpath("data") .. "/mason/bin/jdtls"
  if vim.fn.filereadable(mason) == 1 then
    jdtls_bin = mason
  end
end
assert(jdtls_bin ~= "", "jdtls não está no PATH nem no Mason")

local root_a, file_a = fixtures.maven_project("lsp-a", "com.demo.a", "Alpha")
local root_b, file_b = fixtures.maven_project("lsp-b", "com.demo.b", "Beta")

vim.cmd("edit " .. vim.fn.fnameescape(file_a))
jdtls.start_or_attach({
  cmd = { jdtls_bin, "-data", root_a .. "-data" },
  root_dir = root_a,
})
local attached_a = fixtures.wait_for(30000, function()
  return lsp.client(0) ~= nil
end)
assert(attached_a, "JDTLS A não anexou")

vim.cmd("edit " .. vim.fn.fnameescape(file_b))
jdtls.start_or_attach({
  cmd = { jdtls_bin, "-data", root_b .. "-data" },
  root_dir = root_b,
})
local attached_b = fixtures.wait_for(30000, function()
  local client = lsp.client(0)
  return client ~= nil and client.root_dir == root_b
end)
assert(attached_b, "JDTLS B não anexou ou usou o root errado")

local client_a = lsp.client(vim.fn.bufnr(file_a))
local client_b = lsp.client(vim.fn.bufnr(file_b))
assert(client_a and client_b, "helper não encontrou os dois clientes")
assert(client_a.root_dir == root_a, "cliente A com root errado: " .. tostring(client_a.root_dir))
assert(client_b.root_dir == root_b, "cliente B com root errado: " .. tostring(client_b.root_dir))
assert(client_a.id ~= client_b.id, "o mesmo cliente foi usado para os dois buffers")

-- buffer sem JDTLS não pode herdar um cliente arbitrário
local scratch = vim.api.nvim_create_buf(false, true)
assert(lsp.client(scratch) == nil, "buffer sem JDTLS recebeu cliente global")

-- o cliente global do jc.nvim não serve os dois roots ao mesmo tempo
local jc_ok, jc = pcall(require, "jc.lsp")
assert(jc_ok and type(jc.get_jdtls_client) == "function", "jc.lsp indisponível")
local global_client = jc.get_jdtls_client()
assert(global_client ~= nil, "jc.lsp não encontrou cliente global")
local serves_a = global_client.root_dir == root_a
local serves_b = global_client.root_dir == root_b
assert(not (serves_a and serves_b), "um cliente global não deveria servir os dois projetos")
assert(lsp.global_count() >= 2, "esperava dois clientes JDTLS")
local guard = lsp.jc_global_reason("operação interna de teste")
assert(guard ~= nil, "operacao interna do jc deveria ser bloqueada por ambiguidade")

print("lsp_clients_spec: OK")
vim.cmd("qa!")

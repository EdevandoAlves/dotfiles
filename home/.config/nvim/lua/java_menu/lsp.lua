-- java_menu/lsp.lua
-- Seleção do cliente JDTLS associado ao buffer de origem.
--
-- O jc.nvim resolve o cliente globalmente (`jc.lsp.get_jdtls_client()`), o que
-- funciona bem com um projeto por sessão, mas é ambíguo com dois projetos Java
-- independentes abertos ao mesmo tempo. Aqui o Java Menu escolhe o cliente
-- pelo buffer e usa APIs do Neovim; nenhum servidor é iniciado ou reconfigurado.

local M = {}

---Cliente JDTLS anexado ao buffer (nil quando não há cliente associado).
---@param bufnr number|nil
---@return vim.lsp.Client|nil
function M.client(bufnr)
  bufnr = bufnr and bufnr > 0 and bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end
  local clients = vim.lsp.get_clients({ name = "jdtls", bufnr = bufnr })
  return clients[1]
end

---Cliente associado ao buffer + motivo legível quando não há cliente.
---@param bufnr number|nil
---@return vim.lsp.Client|nil client
---@return string|nil reason
function M.client_or_reason(bufnr)
  bufnr = bufnr and bufnr > 0 and bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil, "o buffer alvo não existe mais"
  end
  local clients = vim.lsp.get_clients({ name = "jdtls", bufnr = bufnr })
  if #clients == 0 then
    return nil, "jdtls não está anexado a este buffer"
  end
  return clients[1], nil
end

---Encoding do cliente, com o padrão do nvim-jdtls quando indisponível.
---@param client vim.lsp.Client|nil
---@return string
function M.encoding(client)
  return (client and client.offset_encoding) or "utf-16"
end

---Motivo para bloquear APIs do jc que resolvem o cliente globalmente.
---O jc chama `jc.lsp.get_jdtls_client()`/`executeCommand()` sem bufnr; com dois
---projetos Java abertos a escolha é ambígua. APIs desejadas no jc.nvim:
---`get_jdtls_client(bufnr)`, `jdtls_request(bufnr, ...)` já direcionado e
---`executeCommand(command, callback, { bufnr = bufnr })`.
---@param op string|nil rótulo da operação para a mensagem
---@return string|nil reason
function M.jc_global_reason(op)
  local count = #vim.lsp.get_clients({ name = "jdtls" })
  if count <= 1 then
    return nil
  end
  local what = op and (" (" .. op .. ")") or ""
  return ("operação do jc.nvim indisponível com %d projetos Java abertos%s: o jc resolve o cliente jdtls globalmente e não aceita bufnr/cliente nesta API"):format(
    count,
    what
  )
end

---Número de clientes JDTLS da sessão (para testes).
---@return integer
function M.global_count()
  return #vim.lsp.get_clients({ name = "jdtls" })
end

return M

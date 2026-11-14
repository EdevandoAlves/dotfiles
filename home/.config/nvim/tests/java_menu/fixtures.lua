-- Fixtures para specs do Java Menu.
-- Não inicia JDTLS nem altera configuração: apenas cria projetos temporários.

local M = {}

local function write(path, text)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(vim.split(vim.trim(text) .. "\n", "\n", { plain = true }), path)
end

---Projeto Maven single-module com um arquivo Java.
---@param label string
---@param pkg string
---@param class_name string
---@return string root, string main_path
function M.maven_project(label, pkg, class_name)
  local root = vim.fs.normalize(vim.fn.tempname() .. "/java-menu-" .. label)
  local rel_pkg = pkg:gsub("%.", "/")
  local main_path = root .. "/src/main/java/" .. rel_pkg .. "/" .. class_name .. ".java"

  write(root .. "/pom.xml", [[
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.java.menu.test</groupId>
  <artifactId>]] .. label .. [[</artifactId>
  <version>1.0</version>
  <properties>
    <maven.compiler.release>21</maven.compiler.release>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
  </properties>
</project>
]])

  write(main_path, [[
package ]] .. pkg .. [[;

public class ]] .. class_name .. [[ {
  public String name() {
    return "]] .. class_name .. [[";
  }
}
]])

  return root, main_path
end

---Espera até `predicate()` ser verdadeira.
---@param timeout_ms integer
---@param predicate fun(): boolean
---@return boolean
function M.wait_for(timeout_ms, predicate)
  return vim.wait(timeout_ms or 30000, predicate, 100)
end

return M

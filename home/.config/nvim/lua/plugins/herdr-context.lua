-- Plugin: herdr-context.nvim — envia contexto (seleção, símbolo, hunk,
-- diagnósticos) do nvim para um agente vivo do Herdr, sem submeter.
-- Só ativa quando o nvim roda dentro de um pane do Herdr (HERDR_ENV=1).
-- Também exige o lado Herdr: herdr plugin install makyinmars/herdr-context.nvim

return {
  "makyinmars/herdr-context.nvim",
  cond = vim.env.HERDR_ENV == "1",
  lazy = false, -- mantém :checkhealth herdr-context disponível antes do 1º mapping
  opts = {},
  keys = {
    {
      "<leader>ac",
      function()
        require("herdr-context").compose()
      end,
      mode = { "n", "v" },
      desc = "Compose Herdr Context",
    },
    {
      "<leader>ap",
      function()
        require("herdr-context").prompt()
      end,
      mode = { "n", "v" },
      desc = "Prompt Herdr with Code Context",
    },
    {
      "<leader>ay",
      function()
        require("herdr-context").reference()
      end,
      mode = { "n", "v" },
      desc = "Send Reference to Herdr Agent",
    },
    {
      "<leader>aY",
      function()
        require("herdr-context").send()
      end,
      mode = { "n", "v" },
      desc = "Send Context to Herdr Agent",
    },
    {
      "<leader>ad",
      function()
        require("herdr-context").diagnostics()
      end,
      mode = { "n", "v" },
      desc = "Send Diagnostics to Herdr Agent",
    },
    {
      "<leader>at",
      function()
        require("herdr-context").select_target()
      end,
      desc = "Select Herdr Agent",
    },
    {
      "<leader>aa",
      function()
        require("herdr-context").agents()
      end,
      desc = "Toggle Herdr Agents",
    },
    {
      "<leader>ar",
      function()
        require("herdr-context").refresh()
      end,
      desc = "Refresh Herdr Agents",
    },
  },
}

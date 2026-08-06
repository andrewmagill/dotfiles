-- A colorscheme, loaded eagerly and early so the UI is themed from the start.
-- This is also the simplest possible plugin spec — a good first proof that
-- lazy.nvim is installing and loading plugins correctly.
return {
  "folke/tokyonight.nvim",
  lazy = false,     -- load during startup, not on a trigger
  priority = 1000,  -- load before other plugins so highlights are set first
  config = function()
    require("tokyonight").setup({ style = "night" })
    vim.cmd.colorscheme("tokyonight")
  end,
}

-- lualine: statusline.
--
-- Kept ICON-FREE to match our Sono font (no Nerd Font glyphs): plain `|`
-- separators instead of powerline arrows, no devicons, and ASCII symbols for the
-- diff/diagnostics components. Theme "auto" derives its colors from the active
-- colorscheme (kanagawa), so it matches without a dedicated lualine theme.
return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  opts = {
    options = {
      theme = "auto",
      icons_enabled = false,
      globalstatus = true, -- one statusline across all splits (laststatus=3)
      component_separators = { left = "|", right = "|" },
      section_separators = { left = "", right = "" },
    },
    sections = {
      lualine_a = { "mode" },
      lualine_b = {
        "branch",
        { "diff", symbols = { added = "+", modified = "~", removed = "-" } },
        { "diagnostics", symbols = { error = "E:", warn = "W:", info = "I:", hint = "H:" } },
      },
      lualine_c = { { "filename", path = 1 } }, -- relative path
      lualine_x = { "filetype", "encoding" },
      lualine_y = { "progress" },
      lualine_z = { "location" },
    },
  },
}

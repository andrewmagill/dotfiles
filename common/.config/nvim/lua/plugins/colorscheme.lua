-- Colorscheme: menisadi/kanagawa.vim — a lightweight Vimscript kanagawa that
-- mimics the "wave" variant (a bit brighter). It's a classic colors/ script,
-- so there's no setup() call — just select it.
return {
  "menisadi/kanagawa.vim",
  lazy = false,     -- load during startup, not on a trigger
  priority = 1000,  -- load before other plugins so highlights are set first
  config = function()
    vim.cmd.colorscheme("kanagawa")
    vim.g.colors_name = "kanagawa"  -- this Vimscript scheme omits it; set for plugins that read it

    -- Fallback: if this doesn't work out, switch to Neovim's built-in "slate"
    -- colorscheme (no plugin needed) — comment the line above and uncomment below.
    -- vim.cmd.colorscheme("slate")
  end,
}

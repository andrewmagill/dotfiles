-- ~/.config/nvim/init.lua — entry point.
--
-- Load order matters:
--   1. leader keys BEFORE any plugin loads (plugins register <leader> maps at
--      load time, so the leader must already be set)
--   2. core editor config (pure Lua, no plugins)
--   3. the plugin manager, which then loads specs from lua/plugins/

-- 1. Leaders. Space is an ergonomic, widely-used choice.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- 2. Core config. Neovim automatically adds lua/ to its module path, so
--    require("options") finds lua/options.lua.
require("options")
require("keymaps")
require("autocmds")

-- 3. Bootstrap lazy.nvim: on a fresh machine, clone it into the data dir and put
--    it on the runtimepath. (Someone has to install the installer — this is the
--    one manual step a plugin manager can't do for itself.)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- 4. Load every spec in lua/plugins/*.lua and let lazy manage them. lazy writes
--    a lazy-lock.json (pinned plugin versions) into this config dir — commit it
--    to keep all machines in sync.
require("lazy").setup({
  spec = { { import = "plugins" } },
  install = { colorscheme = { "habamax" } }, -- builtin theme shown during first install
  checker = { enabled = false },             -- don't auto-check for plugin updates
})

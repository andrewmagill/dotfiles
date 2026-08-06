-- lazydev.nvim teaches lua_ls about the Neovim API (vim.*, vim.uv) and your
-- plugin code, so editing THIS config gets accurate completion and no spurious
-- "undefined global vim" warnings. Loads only for Lua files.
return {
  "folke/lazydev.nvim",
  ft = "lua",
  opts = {},
}

-- Global keymaps (plugin-specific maps live with their plugin specs).
local map = vim.keymap.set

-- Clear search highlight on <Esc> in normal mode.
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Window navigation without the <C-w> prefix. Works the same across editor
-- splits and :terminal splits — see notes on Neovim-as-multiplexer.
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Keep the selection after indenting in visual mode (re-select with gv).
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Leave terminal-insert mode with <Esc> (default is the awkward <C-\><C-n>).
map("t", "<Esc>", "<C-\\><C-n>")

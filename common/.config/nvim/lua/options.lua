-- Editor options (vim.opt.*). Pure settings, no plugins.
local opt = vim.opt

-- Line numbers (absolute current line + relative others = easy vertical motions)
opt.number = true
opt.relativenumber = true

-- Indentation — 4-space default; per-filetype ftplugins can override later.
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true      -- tabs insert spaces
opt.smartindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true      -- case-sensitive only when the query has uppercase
opt.incsearch = true

-- UI
opt.termguicolors = true  -- 24-bit color; required by modern colorschemes
opt.signcolumn = "yes"    -- always show the sign column so text doesn't jump
opt.cursorline = true
opt.scrolloff = 8         -- keep context lines above/below the cursor
opt.wrap = false
opt.splitright = true     -- vertical splits open to the right
opt.splitbelow = true     -- horizontal splits open below

-- Persistence — Neovim already stores these under XDG state dirs by default.
opt.undofile = true       -- undo history survives across sessions
opt.swapfile = false

-- Behavior
opt.mouse = "a"
opt.clipboard = "unnamedplus"  -- share the system clipboard (see WSL note below)
opt.updatetime = 250           -- faster CursorHold (diagnostics, etc.)
opt.timeoutlen = 400           -- mapped-sequence timeout

-- NOTE (WSL): "unnamedplus" needs a clipboard provider. Recent Neovim
-- auto-detects clip.exe/powershell under WSL; if copy/paste to Windows doesn't
-- work, install win32yank and it'll be picked up automatically.

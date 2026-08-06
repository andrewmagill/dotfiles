-- Autocommands. Each registers a callback that fires on a Neovim event.
local augroup = vim.api.nvim_create_augroup("user", { clear = true })

-- Briefly highlight text as it's yanked — nice visual confirmation.
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup,
  callback = function()
    (vim.hl or vim.highlight).on_yank()  -- vim.hl in 0.11+, vim.highlight before
  end,
})

-- Return to the last cursor position when reopening a file.
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup,
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local line_count = vim.api.nvim_buf_line_count(args.buf)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

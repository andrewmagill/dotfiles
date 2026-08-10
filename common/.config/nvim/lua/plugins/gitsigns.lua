-- gitsigns: change signs in the sign column, plus the changed-hunk ranges that
-- conform.nvim uses to format only the lines you actually edited.
return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {},
}

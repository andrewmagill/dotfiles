-- Treesitter: parses code into a syntax tree for accurate highlighting and
-- structural motions. Parsers are compiled C, so a C compiler (gcc/clang) must
-- be available — the package lists include gcc for this reason.
--
-- Pinned to the classic `master` branch API (require("nvim-treesitter.configs")).
-- A `main`-branch rewrite exists with a different API; we can migrate later.
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "master",
  build = ":TSUpdate",                       -- (re)compile parsers on update
  event = { "BufReadPost", "BufNewFile" },   -- load when a real file is opened
  config = function()
    require("nvim-treesitter.configs").setup({
      ensure_installed = {
        "lua", "vim", "vimdoc", "bash", "python", "c",
        "typescript", "tsx", "javascript", "json", "yaml",
        "markdown", "markdown_inline",  -- inline must accompany markdown (injection)
      },
      auto_install = true,        -- install a missing parser when you open a file
      highlight = { enable = true },
      indent = { enable = true },
    })
  end,
}

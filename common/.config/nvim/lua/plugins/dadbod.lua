-- Database workflow (SQL-first, deliberately no generic SQL LSP — see lsp.lua):
--   vim-dadbod             run the query under the cursor / visual selection
--                          against a live DB. Speaks psql (Postgres), sqlcmd
--                          (SQL Server), sqlite3 — all installed by bootstrap.
--   vim-dadbod-ui          drawer UI: connections, schema browsing, saved queries
--   vim-dadbod-completion  live-schema completion (table/column names) → blink.cmp
--
-- CONNECTIONS ARE NEVER TRACKED — they contain credentials. They live only in
-- the machine-local layers:
--   * :DBUIAddConnection persists to stdpath("data")/db_ui (outside the repo)
--   * or export DBUI_URL (+ DBUI_NAME) in $ZSH_LOCAL_DIR/*.secrets.zsh
-- The local dev DB needs no secret at all: `postgresql:///$USER` connects over
-- the unix socket via peer auth.
return {
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = {
      { "tpope/vim-dadbod", lazy = true },
      { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
    },
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
    keys = {
      { "<leader>db", "<cmd>DBUIToggle<cr>", desc = "Database UI" },
    },
    init = function()
      vim.g.db_ui_use_nerd_fonts = 0   -- icon-free, like the rest of the setup (Sono)
      -- Saved queries + connections added via the UI: XDG data dir, not $HOME
      -- and not the repo.
      vim.g.db_ui_save_location = vim.fn.stdpath("data") .. "/db_ui"
    end,
  },

  -- Feed dadbod's live-schema completion into blink.cmp on SQL buffers. This
  -- fragment deep-merges into the main blink.cmp spec (completion.lua);
  -- per_filetype replaces the default source list for sql only, so dadbod is
  -- listed alongside the defaults rather than instead of them.
  {
    "saghen/blink.cmp",
    opts = {
      sources = {
        per_filetype = {
          sql = { "dadbod", "lsp", "path", "snippets", "buffer" },
        },
        providers = {
          dadbod = { name = "Dadbod", module = "vim_dadbod_completion.blink" },
        },
      },
    },
  },
}

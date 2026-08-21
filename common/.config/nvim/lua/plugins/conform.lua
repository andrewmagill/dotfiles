-- conform.nvim — formatting.
--
-- Format-on-save is AIRTIGHT: it formats ONLY the lines changed since the last
-- commit (git hunks from gitsigns), applied bottom-to-top so formatting one
-- region can't shift a later region's line numbers. This keeps a one-line edit
-- to a teammate's file from reformatting the whole file (clean diffs + blame).
--
-- Manual `<leader>f` is the deliberate escape hatch: whole buffer in normal
-- mode, or just the selection in visual mode. `<leader>tf` / :FormatToggle
-- disables auto-format when a file is too messy to touch.
return {
  "stevearc/conform.nvim",
  event = { "BufReadPre", "BufNewFile" },   -- load before the first save
  cmd = { "ConformInfo" },
  dependencies = {
    "lewis6991/gitsigns.nvim",              -- source of changed-hunk ranges
    { "WhoIsSethDaniel/mason-tool-installer.nvim",
      dependencies = { "mason-org/mason.nvim" } },
  },
  config = function()
    -- Ensure the formatter binaries are installed (prettier supports range
    -- formatting, which the airtight save below relies on).
    require("mason-tool-installer").setup({
      ensure_installed = { "prettier", "stylua", "sqlfluff" },
    })

    local conform = require("conform")

    -- prettier covers the web set; stylua for our Lua config. Grow this map as
    -- we add languages (black/ruff, csharpier, shfmt, …).
    conform.setup({
      formatters_by_ft = {
        lua = { "stylua" },
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        json = { "prettier" },
        jsonc = { "prettier" },
        css = { "prettier" },
        scss = { "prettier" },
        html = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        graphql = { "prettier" },
        sql = { "sqlfluff" },
      },

      -- Prefer the project's own prettier (node_modules) so on-save formatting is
      -- byte-identical to the team's CI — including plugins like
      -- prettier-plugin-tailwindcss. Falls back to the mason-global prettier.
      formatters = {
        prettier = {
          command = function(_, ctx)
            local local_bin = vim.fs.find(
              "node_modules/.bin/prettier",
              { path = ctx.dirname, upward = true }
            )[1]
            return local_bin or "prettier"
          end,
        },

        -- sqlfluff needs a dialect (tsql / postgres / sqlite / …). Use the
        -- project's .sqlfluff when one exists — run from its directory so
        -- stdin-mode config discovery finds it, and do NOT pass --dialect
        -- (the CLI flag would override the file). Otherwise fall back to
        -- plain ANSI so formatting still works on stray SQL files.
        sqlfluff = {
          args = function(_, ctx)
            local cfg = vim.fs.find(".sqlfluff", { path = ctx.dirname, upward = true })[1]
            if cfg then return { "format", "-" } end
            return { "format", "--dialect=ansi", "-" }
          end,
          cwd = function(_, ctx)
            local cfg = vim.fs.find(".sqlfluff", { path = ctx.dirname, upward = true })[1]
            return cfg and vim.fs.dirname(cfg) or ctx.dirname
          end,
        },
      },
    })

    -- Format only the git-changed line ranges in `bufnr`, bottom-to-top.
    local function format_changed(bufnr)
      local ok, gs = pcall(require, "gitsigns")
      local hunks = ok and gs.get_hunks(bufnr) or nil

      -- No git baseline (untracked / not in a repo): the whole file is "yours".
      if hunks == nil then
        conform.format({ bufnr = bufnr, async = false, lsp_format = "never" })
        return
      end

      -- Collect the ranges of added/changed lines (skip pure deletions — no
      -- lines remain to format). Gather them ALL before formatting any.
      local ranges = {}
      for _, h in ipairs(hunks) do
        if h.type ~= "delete" and h.added and h.added.count > 0 then
          local s = h.added.start
          local e = s + h.added.count - 1
          local last = vim.api.nvim_buf_get_lines(bufnr, e - 1, e, false)[1] or ""
          ranges[#ranges + 1] = { start = { s, 0 }, ["end"] = { e, #last } }
        end
      end

      -- Bottom-to-top: format lower ranges first so their edits can't invalidate
      -- the (pre-format) line numbers of ranges above them.
      table.sort(ranges, function(a, b) return a.start[1] > b.start[1] end)
      for _, range in ipairs(ranges) do
        conform.format({ bufnr = bufnr, async = false, lsp_format = "never", range = range })
      end
    end

    -- Format-on-save (unless toggled off, globally or per-buffer).
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = vim.api.nvim_create_augroup("user-conform", { clear = true }),
      callback = function(args)
        if vim.g.disable_autoformat or vim.b[args.buf].disable_autoformat then return end
        format_changed(args.buf)
      end,
    })

    -- Manual, deliberate format: whole buffer (normal) or selection (visual).
    vim.keymap.set({ "n", "x" }, "<leader>f", function()
      conform.format({ async = false, lsp_format = "never" })
    end, { desc = "Format buffer / selection" })

    -- Toggle format-on-save.
    local function toggle()
      vim.g.disable_autoformat = not vim.g.disable_autoformat
      vim.notify("Format-on-save " .. (vim.g.disable_autoformat and "disabled" or "enabled"))
    end
    vim.api.nvim_create_user_command("FormatToggle", toggle, { desc = "Toggle format-on-save" })
    vim.keymap.set("n", "<leader>tf", toggle, { desc = "Toggle format-on-save" })
  end,
}

-- LSP wiring. The pieces (see notes/neovim.md for the full walkthrough):
--   mason.nvim            installs server binaries cross-platform
--   mason-lspconfig.nvim  glue between mason and lspconfig
--   nvim-lspconfig        ships each server's base config (cmd, filetypes, root)
--   Neovim's built-in client runs the server and renders results
--   blink.cmp             advertises rich completion capabilities to servers
return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    { "mason-org/mason.nvim", opts = {} },  -- installer (repo moved to mason-org in 2025)
    "mason-org/mason-lspconfig.nvim",
    "saghen/blink.cmp",
  },
  config = function()
    -- Capabilities to advertise to every server (from our completion engine).
    local capabilities = require("blink.cmp").get_lsp_capabilities()

    -- Per-server settings. Add a server here to enable it. Growing toward the
    -- full language set (Python, Ruby, C/C++, C#, Haskell, Clojure, SQL/TSQL/
    -- PL-pgSQL, HCL, LaTeX, …); the Next.js / web subset is enabled first.
    local servers = {
      lua_ls = {
        settings = {
          Lua = {
            completion = { callSnippet = "Replace" },
            -- The `vim` global is provided by lazydev.nvim, so no need to
            -- declare it as a diagnostics global here.
          },
        },
      },
      ts_ls = {},   -- TypeScript/JavaScript (typescript-language-server via Node)
      eslint = {},  -- lint diagnostics + fixes (uses the project's eslint config)

      -- Next.js / web front-end
      html = {},                  -- vscode HTML language server
      cssls = {},                 -- vscode CSS server (css / scss / less)
      jsonls = {},                -- vscode JSON server
      tailwindcss = {},           -- Tailwind CSS (attaches when a tailwind config exists)
      emmet_language_server = {}, -- Emmet expansion in html / css / jsx / tsx

      -- SQL: deliberately NO generic SQL LSP (sqls/sqlls are weakly maintained;
      -- completion comes live from vim-dadbod-completion, lint/format from
      -- sqlfluff via conform — see dadbod.lua / conform.lua). For serious
      -- PL/pgSQL work later, add Supabase's Postgres Language Server here with
      -- `postgres_lsp = {},` — it's opt-in per project regardless
      -- (workspace_required: attaches only under a postgres-language-server.jsonc
      -- root marker), but it's pre-1.0 and twice-renamed, so we're waiting.
    }

    -- Ensure the servers are installed (lua_ls ships as a prebuilt binary, so no
    -- extra language toolchain is required).
    require("mason-lspconfig").setup({
      ensure_installed = vim.tbl_keys(servers),
      -- We enable servers ourselves in the loop below. Without this, v2's
      -- automatic_enable also tries to start installed mason *tools* (stylua,
      -- prettier — installed for conform) as LSP servers, which they aren't:
      -- "Client stylua quit with exit code 2".
      automatic_enable = false,
    })

    -- Register each server's config (merged onto nvim-lspconfig's base) and
    -- enable it. vim.lsp.config()/vim.lsp.enable() is the Neovim 0.11+ native API.
    for name, cfg in pairs(servers) do
      cfg.capabilities = capabilities
      vim.lsp.config(name, cfg)
      vim.lsp.enable(name)
    end

    -- Buffer-local keymaps, applied when ANY server attaches to a buffer.
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("user-lsp-attach", { clear = true }),
      callback = function(args)
        local map = function(keys, fn, desc)
          vim.keymap.set("n", keys, fn, { buffer = args.buf, desc = "LSP: " .. desc })
        end
        map("gd", vim.lsp.buf.definition, "Go to definition")
        map("gr", vim.lsp.buf.references, "References")
        map("gi", vim.lsp.buf.implementation, "Go to implementation")
        map("K", vim.lsp.buf.hover, "Hover docs")
        map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
        map("<leader>ca", vim.lsp.buf.code_action, "Code action")
        map("<leader>e", vim.diagnostic.open_float, "Line diagnostics")
      end,
    })
  end,
}

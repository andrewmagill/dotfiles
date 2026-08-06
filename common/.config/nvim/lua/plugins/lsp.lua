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

    -- Per-server settings. Add a server here to enable it.
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
    }

    -- Ensure the servers are installed (lua_ls ships as a prebuilt binary, so no
    -- extra language toolchain is required).
    require("mason-lspconfig").setup({
      ensure_installed = vim.tbl_keys(servers),
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

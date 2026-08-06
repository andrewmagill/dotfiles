-- Telescope: fuzzy finder over files, live grep, buffers, LSP symbols, etc.
-- It shells out to ripgrep (live_grep) and fd (find_files) — both in the package
-- lists — and uses a compiled native sorter (fzf-native) for fast matching.
return {
  "nvim-telescope/telescope.nvim",
  cmd = "Telescope",
  dependencies = {
    "nvim-lua/plenary.nvim",                 -- lua utility library Telescope needs
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",                        -- compiles the native sorter (needs gcc + make)
    },
    "nvim-telescope/telescope-ui-select.nvim", -- route vim.ui.select (e.g. code actions) through Telescope
  },
  -- Lazy-load on first keypress; each key also loads the plugin.
  keys = {
    { "<leader>ff", "<cmd>Telescope find_files<cr>",           desc = "Find files" },
    { "<leader>fg", "<cmd>Telescope live_grep<cr>",            desc = "Live grep" },
    { "<leader>fb", "<cmd>Telescope buffers<cr>",              desc = "Buffers" },
    { "<leader>fh", "<cmd>Telescope help_tags<cr>",            desc = "Help tags" },
    { "<leader>fr", "<cmd>Telescope oldfiles<cr>",             desc = "Recent files" },
    { "<leader>fd", "<cmd>Telescope diagnostics<cr>",          desc = "Diagnostics" },
    { "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>", desc = "Document symbols" },
  },
  config = function()
    local telescope = require("telescope")
    telescope.setup({
      extensions = {
        ["ui-select"] = { require("telescope.themes").get_dropdown() },
      },
    })
    telescope.load_extension("fzf")        -- use the compiled native sorter
    telescope.load_extension("ui-select")
  end,
}

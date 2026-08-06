-- blink.cmp — the completion engine. It aggregates candidates from several
-- SOURCES (LSP, filesystem paths, snippets, words in open buffers) into the
-- popup menu, ranked by a fast Rust fuzzy matcher that ships prebuilt in the
-- release tags (so no Rust toolchain is needed when pinned to a version).
return {
  "saghen/blink.cmp",
  version = "*",             -- use a release tag → prebuilt fuzzy-matcher binary
  event = "InsertEnter",
  opts = {
    -- 'default' preset: <C-space> open, <C-y> accept, <C-n>/<C-p> select,
    -- <C-e> cancel. (Arrow keys also select.)
    keymap = { preset = "default" },
    appearance = { nerd_font_variant = "mono" },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
    completion = {
      documentation = { auto_show = true },  -- preview docs for the selected item
    },
  },
}

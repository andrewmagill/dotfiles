-- WezTerm configuration.
-- Colors ported 1:1 from the Alacritty "SeaShells" scheme
-- (see common/.config/alacritty/alacritty.toml).
local wezterm = require("wezterm")

return {
  color_scheme = "SeaShells (custom)",
  color_schemes = {
    ["SeaShells (custom)"] = {
      background = "#09141b",
      foreground = "#deb88d",

      cursor_bg = "#fca02f",
      cursor_fg = "#08131a",
      cursor_border = "#fca02f",

      selection_bg = "#1e4962",
      selection_fg = "#fee4ce",

      -- ANSI order: black red green yellow blue magenta cyan white
      ansi = {
        "#17384c", "#d15123", "#027c9b", "#fca02f",
        "#1e4950", "#68d4f1", "#50a3b5", "#deb88d",
      },
      brights = {
        "#434b53", "#d48678", "#628d98", "#fdd39f",
        "#1bbcdd", "#bbe3ee", "#87acb4", "#fee4ce",
      },
    },
  },
}

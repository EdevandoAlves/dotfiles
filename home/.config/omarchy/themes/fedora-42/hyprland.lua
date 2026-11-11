-- Fedora/GNOME-inspired window chrome: 12px corners, Adwaita-like soft
-- shadows, and a hairline focus outline instead of a thick neon frame.
-- The shell mirrors decoration:rounding and general:gaps_out, so popups
-- and panels adopt the same geometry. Animations stay at Omarchy's defaults.
local active_border_color = "#3584e4"
local inactive_border_color = "rgba(ffffff1a)"

hl.config({
  general = {
    gaps_in = 4,
    gaps_out = 8,
    border_size = 1,

    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },

  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },

  decoration = {
    rounding = 12,

    dim_inactive = true,
    dim_strength = 0.10,

    shadow = {
      enabled = true,
      range = 30,
      render_power = 3,
      color = "rgba(00000066)",
      color_inactive = "rgba(00000033)",
      offset = { 0, 8 },
    },
  },
})

-- Adwaita mouse cursors, matching the icon theme.
hl.env("XCURSOR_THEME", "Adwaita")

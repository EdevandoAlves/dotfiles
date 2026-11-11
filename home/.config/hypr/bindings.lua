-- Keep only your personal keybinding overrides here. Add new bindings with
-- o.bind or replace defaults with o.rebind.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding. o.rebind takes the same arguments as o.bind.
-- This example replaces the default file manager with Flea.
-- o.rebind("SUPER + SHIFT + F", "File manager", { launch = "flea" })

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, { panel = "omarchy.emojis" })
--
-- Directional focus, vim-style (replaces defaults: SUPER+J togglesplit,
-- SUPER+K keybindings menu, SUPER+L workspace layout cycle).
o.rebind("SUPER + H", "Focus on left window", hl.dsp.focus({ direction = "l" }))
o.rebind("SUPER + J", "Focus on below window", hl.dsp.focus({ direction = "d" }))
o.rebind("SUPER + K", "Focus on above window", hl.dsp.focus({ direction = "u" }))
o.rebind("SUPER + L", "Focus on right window", hl.dsp.focus({ direction = "r" }))

-- Move window directionally (same swap behavior as SUPER + SHIFT + arrows).
o.bind("SUPER + SHIFT + H", "Swap window to the left", hl.dsp.window.swap({ direction = "l" }))
o.bind("SUPER + SHIFT + J", "Swap window down", hl.dsp.window.swap({ direction = "d" }))
o.bind("SUPER + SHIFT + K", "Swap window up", hl.dsp.window.swap({ direction = "u" }))
o.bind("SUPER + SHIFT + L", "Swap window to the right", hl.dsp.window.swap({ direction = "r" }))

-- Bitwarden desktop (verified: Exec=bitwarden-desktop in bitwarden.desktop).
o.rebind("SUPER + SHIFT + SLASH", "Bitwarden", { launch = "bitwarden-desktop" })

-- Salvar clip de jogo (replay buffer do gpu-screen-recorder, últimos 60s).
o.rebind("SUPER + SLASH", "Salvar clip de jogo (últimos 60s)", "gsr-clip.sh")

-- Iniciar/parar gravação de sessão (o replay buffer continua ativo).
o.rebind("SUPER + COMMA", "Iniciar/parar gravação", "gsr-record.sh")

-- Screenshot da tela cheia (salvo em /data/midia/fotos/screenshots).
o.bind("SUPER + PERIOD", "Screenshot (tela cheia)", "omarchy capture screenshot fullscreen save")

-- Popup de atalhos em SUPER + ; (SUPER + C volta a ser o universal copy padrão).
o.bind("SUPER + semicolon", "Keybindings", "omarchy-menu-keybindings")

-- ZapFast (WhatsApp nativo) em SUPER + SHIFT + G.
o.rebind("SUPER + SHIFT + G", "WhatsApp (ZapFast)", { launch = "zapfast-x11", focus = "^zapfast$" })

-- Limusic (YouTube Music nativo) em SUPER + SHIFT + M.
o.rebind("SUPER + SHIFT + M", "Music (Limusic)", { launch = "limusic-app", focus = "^limusic-app$" })

-- Signal herda o atalho que era do WhatsApp Web (que agora é o ZapFast).
o.rebind("SUPER + SHIFT + ALT + G", "Signal", { omarchy = "signal" })

-- Waystone (overlay de price check do PoE2): ALT+Z consulta preço, ALT+X escaneia
-- únicos. O Waystone registra os atalhos via portal (GlobalShortcuts), mas o
-- Hyprland com config em Lua não aceita mais `hyprctl keyword bind`, então o
-- bind dinâmico que ele tenta criar falha silenciosamente. Amarramos aqui, e só
-- disparamos quando a janela do jogo está em foco.
local function waystone_shortcut(id)
  return function()
    local window = hl.get_active_window()
    local class = window and (window.class or ""):lower() or ""
    -- Aceita tanto XWayland quanto Wayland nativo (a classe muda conforme o
    -- backend do Proton): pathofexilesteam.exe, steam_app_2694490, ...
    if class:find("exile", 1, true) or class == "steam_app_2694490" then
      hl.dispatch(hl.dsp.global("waystone:" .. id))
    end
  end
end

o.bind("ALT + Z", "PoE2 price check (Waystone)", waystone_shortcut("price-check"), { non_consuming = true })
o.bind("ALT + X", "PoE2 unique scan (Waystone)", waystone_shortcut("unique-scan"), { non_consuming = true })

-- Fecha o painel do Waystone com Esc. O app tenta criar esse bind sozinho com
-- `hyprctl keyword bind`, que o Hyprland com config em Lua não aceita mais. O
-- painel é uma layer-shell (namespace gtk4-layer-shell), então amarramos Esc só
-- enquanto ela existe e removemos quando fecha (sem atrapalhar outros Esc).
local waystone_layers = 0
local waystone_esc = nil

local function is_waystone_layer(layer)
  return layer ~= nil and layer.namespace == "gtk4-layer-shell"
end

hl.on("layer.opened", function(layer)
  if not is_waystone_layer(layer) then return end
  waystone_layers = waystone_layers + 1
  if waystone_esc == nil then
    waystone_esc = hl.bind("Escape", hl.dsp.global("waystone:panel-close"),
      { description = "Close Waystone panel" })
  end
end)

hl.on("layer.closed", function(layer)
  if not is_waystone_layer(layer) then return end
  waystone_layers = math.max(0, waystone_layers - 1)
  if waystone_layers == 0 and waystone_esc ~= nil then
    waystone_esc:remove()
    waystone_esc = nil
  end
end)

-- ── Omacale ─────────────────────────────────────────────────────────────────
-- Drawers, painéis e foco da barra do shell Omacale (plugin omacale.bar).
-- SUPER + A substitui o "Selecionar tudo" do Omarchy; os demais estavam livres.
o.rebind("SUPER + A", "Omacale launcher", "omarchy-shell omacale launcher")
o.bind("SUPER + D", "Omacale dashboard", "omarchy-shell omacale dashboard")
o.bind("SUPER + N", "Omacale notifications sidebar", "omarchy-shell omacale sidebar")
o.bind("SUPER + U", "Omacale quick toggles", "omarchy-shell omacale utilities")
o.bind("SUPER + SHIFT + ESCAPE", "Omacale session menu", "omarchy-shell omacale session")
-- Settings em SUPER + CTRL + I (SUPER + SHIFT + I troca o idioma de entrada).
o.bind("SUPER + CTRL + I", "Omacale settings", "omarchy-shell omacale settings")
o.bind("SUPER + ALT + D", "Omacale media", "omarchy-shell omacale dashboardTab media")
o.bind("SUPER + ALT + P", "Omacale performance", "omarchy-shell omacale dashboardTab performance")
-- Foco da barra: j/k/setas andam, Enter/Space acionam, 1..9 trocam de workspace.
o.bind("SUPER + CTRL + code:19", "Omacale bar focus", "omarchy-shell omacale barFocus")

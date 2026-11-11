.pragma library

// Omacale settings, laid out like Caelestia's Nexus: top-level pages grouped
// by category in the navigation pane, sub-pages opened from "nav" rows.
//
// Row types:
//   section  { text }
//   toggle   { key, label, subtext }
//   stepper  { key, label, subtext, from, to, step }
//   slider   { key, label, icon, from, to, step, unit: "%" | "x" | "px", commit?: "release" }
//   select   { key, label, subtext, options: [{ value, label, icon }] }
//   text     { key, label, subtext, placeholder }
//   nav      { icon, label, subtext, page, status? }
//   custom   { comp }  — rendered by a dedicated component
// Any row can carry `when: { key, value }` (or a list of them, all of which
// must hold); it is dimmed and inert unless that setting has that value, or
// left out altogether with `hide: true`.

// "00:00" … "23:30", for the night light's custom times.
function halfHours() {
  var out = []
  for (var h = 0; h < 24; h++) for (var m = 0; m < 60; m += 30) {
    var t = (h < 10 ? "0" : "") + h + ":" + (m ? "30" : "00")
    out.push({ value: t, label: t })
  }
  return out
}

var LIQUID_ON = { key: "liquid.enabled", value: true }
var LIQUID_CUSTOM = [LIQUID_ON, { key: "liquid.preset", value: "custom" }]
var GLASS_ON = { key: "glass.enabled", value: true }

// Does a row's `when` hold, `get` reading a setting.
// A list may reach here as QML's own sequence, which Array.isArray doesn't
// know, so a single condition is told by its `key`.
function whenHolds(when, get) {
  if (!when) return true
  var all = when.key !== undefined ? [when] : when
  for (var i = 0; i < all.length; i++) if (get(all[i].key) !== all[i].value) return false
  return true
}

var pages = [
  {
    id: "style", label: "Papel de parede e estilo", icon: "palette", category: "appearance",
    description: "Paleta, esquema, transparência, escala",
    rows: [
      { type: "custom", comp: "preview" },
      { type: "nav", icon: "wallpaper", label: "Papéis de parede", subtext: "Todos os papéis de parede do tema atual", page: "wallpapers" },
      { type: "nav", icon: "palette", label: "Temas", subtext: "Todos os temas do Omarchy instalados", page: "themes" },
      { type: "section", text: "Cores" },
      { type: "select", key: "appearance.palette", label: "Paleta", subtext: "Cores Material geradas a partir de uma semente, ou as cores do próprio tema do Omarchy", options: [
        { value: "material", label: "Material", icon: "palette" },
        { value: "omarchy", label: "Omarchy", icon: "format_paint" }
      ] },
      { type: "custom", comp: "seeds", when: { key: "appearance.palette", value: "material" } },
      { type: "toggle", key: "appearance.seedFollowsTheme", when: { key: "appearance.palette", value: "material" }, label: "Seguir a troca de tema", subtext: "Trocar o tema do Omarchy descarta uma semente personalizada escolhida em outro tema" },
      { type: "toggle", key: "appearance.omarchySurfaces", when: { key: "appearance.palette", value: "material" }, label: "Colorir também os menus do Omarchy", subtext: "Os menus, pop-ups, notificações e seletores do próprio Omarchy nestas cores (um bloco marcado em ~/.config/omarchy/shell.toml, removido quando desligado). O destaque deles continua o do tema" },
      { type: "select", key: "appearance.variant", when: { key: "appearance.palette", value: "material" }, label: "Esquema", subtext: "Como a paleta é construída a partir da cor semente", options: [
        { value: "tonalspot", label: "Ponto tonal", icon: "palette" },
        { value: "vibrant", label: "Vibrante", icon: "colors" },
        { value: "expressive", label: "Expressivo", icon: "gradient" },
        { value: "fidelity", label: "Fidelidade", icon: "filter_vintage" },
        { value: "content", label: "Conteúdo", icon: "image" },
        { value: "fruitsalad", label: "Salada de frutas", icon: "nutrition" },
        { value: "rainbow", label: "Arco-íris", icon: "looks" },
        { value: "neutral", label: "Neutro", icon: "contrast" },
        { value: "monochrome", label: "Monocromático", icon: "tonality" }
      ] },
      { type: "select", key: "appearance.mode", when: { key: "appearance.palette", value: "material" }, label: "Modo", subtext: "Superfícies claras ou escuras", options: [
        { value: "auto", label: "Seguir o tema", icon: "brightness_auto" },
        { value: "dark", label: "Escuro", icon: "dark_mode" },
        { value: "light", label: "Claro", icon: "light_mode" }
      ] },
      { type: "toggle", key: "appearance.pureBlack", label: "Painéis pretos puros", subtext: "Somente no modo escuro: a moldura e as gavetas ficam em preto puro (cartões um tom mais claros) para sumir na borda preta do monitor" },
      { type: "section", text: "Transparência" },
      { type: "toggle", key: "appearance.transparency.enabled", label: "Transparência", subtext: "Moldura e gavetas translúcidas com desfoque do fundo" },
      { type: "slider", key: "appearance.transparency.base", label: "Opacidade da superfície", icon: "opacity", from: 0.3, to: 1, step: 0.01, unit: "%" },
      { type: "slider", key: "appearance.transparency.layers", label: "Opacidade dos cartões", icon: "layers", from: 0.1, to: 1, step: 0.01, unit: "%" },
      { type: "section", text: "Escala" },
      { type: "select", key: "appearance.scale.source", label: "Escala da interface", subtext: "O padrão segue o tamanho da fonte do Omarchy", options: [
        { value: "omarchy", label: "Padrão", icon: "sync" },
        { value: "custom", label: "Personalizado", icon: "tune" }
      ] },
      // Presets rather than a slider: Settings re-lays itself out at the new
      // size, which would pull a slider out from under the pointer.
      { type: "select", key: "appearance.scale.ui", when: { key: "appearance.scale.source", value: "custom" }, label: "Tamanho", subtext: "Textos, ícones, espaçamento, o bar e as gavetas", options: [
        { value: "0.75", label: "75%" },
        { value: "0.85", label: "85%" },
        { value: "0.9", label: "90%" },
        { value: "1", label: "100%" },
        { value: "1.1", label: "110%" },
        { value: "1.25", label: "125%" },
        { value: "1.5", label: "150%" }
      ] },
      { type: "slider", key: "appearance.scale.font", label: "Tamanho do texto", icon: "format_size", from: 0.5, to: 1.5, step: 0.05, unit: "x", commit: "release" },
      { type: "slider", key: "appearance.scale.padding", label: "Preenchimento", icon: "padding", from: 0.5, to: 1.5, step: 0.05, unit: "x", commit: "release" },
      { type: "slider", key: "appearance.scale.spacing", label: "Espaçamento", icon: "space_bar", from: 0.5, to: 1.5, step: 0.05, unit: "x", commit: "release" },
      { type: "slider", key: "appearance.scale.rounding", label: "Arredondamento", icon: "rounded_corner", from: 0, to: 1.5, step: 0.05, unit: "x", commit: "release" }
    ]
  },
  {
    // The frame and the drawers' shape and surface. Everything that moves
    // is on the Motion page ("liquid").
    id: "frame", label: "Moldura", icon: "rounded_corner", category: "appearance",
    description: "Borda, arredondamento, mesclagem, sombra",
    rows: [
      { type: "section", text: "Borda" },
      { type: "slider", key: "border.thickness", label: "Espessura da borda", icon: "border_outer", from: 0, to: 30, step: 1, unit: "px" },
      { type: "slider", key: "border.rounding", label: "Arredondamento dos cantos (na escala 100%)", icon: "rounded_corner", from: 0, to: 48, step: 1, unit: "px" },
      { type: "slider", key: "border.smoothing", label: "Mesclagem das gavetas (na escala 100%)", icon: "join", from: 2, to: 40, step: 1, unit: "px" },
      { type: "section", text: "Superfície" },
      { type: "toggle", key: "appearance.shadow", label: "Sombra", subtext: "Sombra suave sob a moldura e as gavetas" },
      { type: "nav", icon: "blur_on", label: "Vidro", subtext: "Gavetas translúcidas iluminadas na borda", page: "glass", status: "glass.enabled" }
    ]
  },
  {
    // Omacale's own (core/Glass.qml): Vitreus's glass on Caelestia's
    // drawers. Off, nothing on this page changes anything.
    id: "glass", label: "Vidro", icon: "blur_on", category: "appearance",
    description: "Gavetas translúcidas iluminadas na borda",
    rows: [
      { type: "toggle", key: "glass.enabled", label: "Vidro", subtext: "A moldura e as gavetas viram vidro sobre o desfoque do Hyprland, iluminadas ao longo da borda. Desligado, são desenhadas como no Caelestia" },
      { type: "section", text: "Vidro", when: GLASS_ON },
      { type: "slider", key: "glass.opacity", when: GLASS_ON, label: "Opacidade", icon: "opacity", from: 0.3, to: 1, step: 0.01, unit: "%" },
      { type: "select", key: "glass.tone", when: GLASS_ON, label: "Tom", icon: "contrast", subtext: "O vidro fosco clareia o que está atrás, como o do Vitreus; o vidro fumê escurece", options: [
        { value: "milk", label: "Fosco", icon: "ac_unit" },
        { value: "clear", label: "Transparente", icon: "circle" },
        { value: "smoke", label: "Fumê", icon: "dark_mode" }
      ] },
      { type: "slider", key: "glass.toneAmount", when: [GLASS_ON, { key: "glass.tone", value: "milk" }], hide: true, label: "Fosco", icon: "gradient", from: 0, to: 1, step: 0.05, unit: "%" },
      { type: "slider", key: "glass.toneAmount", when: [GLASS_ON, { key: "glass.tone", value: "smoke" }], hide: true, label: "Fumaça", icon: "gradient", from: 0, to: 1, step: 0.05, unit: "%" },
      { type: "section", text: "Lente", when: GLASS_ON },
      { type: "toggle", key: "glass.lens", when: GLASS_ON, label: "Vidro real", subtext: "O vidro mostra o que está atrás por conta própria -- o papel de parede e as janelas, reconstruídos a partir das próprias capturas -- curvado na borda, fosco do seu jeito, tonalizado e ampliado. Desligado, é uma película sobre o desfoque do Hyprland" },
      { type: "slider", key: "glass.lensFrost", when: [GLASS_ON, { key: "glass.lens", value: true }], label: "Fosco", icon: "blur_on", subtext: "0 é vidro transparente", from: 0, to: 1, step: 0.05, unit: "%" },
      { type: "slider", key: "glass.refraction", when: [GLASS_ON, { key: "glass.lens", value: true }], label: "Refração", icon: "lens_blur", from: 0, to: 2, step: 0.05, unit: "x" },
      { type: "slider", key: "glass.dispersion", when: [GLASS_ON, { key: "glass.lens", value: true }], label: "Franjas coloridas", icon: "looks", from: 0, to: 1, step: 0.05, unit: "%" },
      { type: "slider", key: "glass.dome", when: [GLASS_ON, { key: "glass.lens", value: true }], label: "Ampliar", icon: "zoom_in", from: 0, to: 1, step: 0.05, unit: "%" },
      { type: "toggle", key: "glass.motion", when: [GLASS_ON, { key: "glass.lens", value: true }], label: "Líquido ao mover", subtext: "Uma gaveta ou cartão que se move curva e separa a luz com mais força por um instante, e assenta quando para" },
      { type: "toggle", key: "glass.nested", when: [GLASS_ON, { key: "glass.lens", value: true }], label: "Cartões de vidro", subtext: "Os cartões de uma gaveta são vidro transparente próprio, curvando o vidro da gaveta ao longo da borda. Desligado, são uma película" },
      { type: "slider", key: "glass.bevel", when: GLASS_ON, label: "Chanfro", icon: "rounded_corner", from: 6, to: 40, step: 1, unit: "px" },
      { type: "section", text: "Desfoque do Hyprland", when: GLASS_ON },
      { type: "toggle", key: "glass.tuneBlur", when: GLASS_ON, label: "Ajustar o desfoque do Hyprland para o vidro", subtext: "Atrás dos avisos, e o vidro sem a lente. Com o vidro ligado: sem granulação, cor natural, o fosco abaixo. Suas próprias configurações de desfoque voltam quando desliga" },
      { type: "slider", key: "glass.frost", when: [GLASS_ON, { key: "glass.tuneBlur", value: true }], label: "Desfoque", icon: "blur_on", from: 1, to: 12, step: 1 },
      { type: "section", text: "Claro", when: GLASS_ON },
      { type: "slider", key: "glass.light", when: GLASS_ON, label: "Luz da borda", icon: "flare", from: 0, to: 2, step: 0.05, unit: "x" },
      { type: "toggle", key: "glass.pointer", when: GLASS_ON, label: "A luz segue o ponteiro", subtext: "Sobre uma gaveta, a luz vem do ponteiro em vez do canto superior esquerdo" }
    ]
  },
  {
    // Omacale's own (core/Liquid.qml, core/Morph.qml): liquid or
    // morph motion on Caelestia's drawers. On Caelestia's, nothing on
    // this page changes anything.
    id: "liquid", label: "Movimento", icon: "water_drop", category: "appearance",
    description: "Velocidade, esticamento, Caelestia, líquido ou morph",
    rows: [
      { type: "custom", comp: "liquidPreview" },
      { type: "custom", comp: "motionStyle", label: "Estilo", icon: "animation", subtext: "Como as gavetas entram e saem: as curvas do Caelestia, molas líquidas, ou morph: um painel por vez, se remodelando no próximo", options: [
        { value: "caelestia", label: "Caelestia", icon: "motion_photos_on" },
        { value: "liquid", label: "Líquido", icon: "water_drop" },
        { value: "morph", label: "Morph", icon: "animation" }
      ] },
      { type: "section", text: "Tempo" },
      { type: "slider", key: "appearance.animScale", label: "Duração da animação", icon: "timer", from: 0.25, to: 2, step: 0.05, unit: "x" },
      { type: "slider", key: "appearance.deformScale", label: "Esticamento da gaveta", icon: "motion_blur", from: 0, to: 3, step: 0.1, unit: "x" },
      { type: "section", text: "Molas", when: LIQUID_ON, hide: true },
      { type: "custom", comp: "liquidPreset", when: LIQUID_ON, hide: true, label: "Predefinição", icon: "water_drop", subtext: "Quão vivas são as molas", options: [
        { value: "subtle", label: "Sutil", icon: "water" },
        { value: "balanced", label: "Equilibrado", icon: "water_drop" },
        { value: "bouncy", label: "Saltitante", icon: "bubble_chart" },
        { value: "custom", label: "Personalizado", icon: "tune" }
      ] },
      { type: "select", key: "liquid.style", when: LIQUID_ON, hide: true, label: "Saída das gavetas", icon: "move_down", subtext: "Deslizar para fora da moldura, ou crescer a partir de uma gota estreita (a barra lateral, os utilitários, as Configurações e a visão geral mantêm o próprio jeito)", options: [
        { value: "slide", label: "Deslizar", icon: "swipe_down" },
        { value: "drop", label: "Gota", icon: "water_drop" }
      ] },
      { type: "section", text: "Personalizado", when: LIQUID_CUSTOM, hide: true },
      { type: "slider", key: "liquid.stiffness", when: LIQUID_CUSTOM, hide: true, label: "Rigidez", icon: "speed", from: 60, to: 600, step: 5 },
      { type: "slider", key: "liquid.damping", when: LIQUID_CUSTOM, hide: true, label: "Amortecimento", icon: "airwave", from: 4, to: 60, step: 1 },
      { type: "slider", key: "liquid.bulge", when: LIQUID_CUSTOM, hide: true, label: "Inchaço do excesso", icon: "expand", from: 0, to: 2, step: 0.05, unit: "x" },
      { type: "slider", key: "liquid.neckWidth", when: LIQUID_CUSTOM, hide: true, label: "Largura do pescoço (na escala 100%)", icon: "join", from: 0, to: 60, step: 1, unit: "px" },
      { type: "slider", key: "liquid.narrow", when: LIQUID_CUSTOM, hide: true, label: "Mais estreito no caminho", icon: "compress", from: 0, to: 0.3, step: 0.01, unit: "%" },
      { type: "slider", key: "liquid.sag", when: LIQUID_CUSTOM, hide: true, label: "Afundamento ao pousar", icon: "south", from: 0, to: 600, step: 10 },
      { type: "slider", key: "liquid.wobble", when: LIQUID_CUSTOM, hide: true, label: "Oscilação ao pousar", icon: "vibration", from: 0, to: 800, step: 10 },
      { type: "section", text: "Forma", when: LIQUID_ON, hide: true },
      { type: "toggle", key: "liquid.neck", when: LIQUID_ON, hide: true, label: "Pescoço líquido", subtext: "Uma gaveta em movimento se une à moldura por um pescoço mais espesso no meio" },
      { type: "toggle", key: "liquid.rounding", when: LIQUID_ON, hide: true, label: "Redondo como uma gota", subtext: "Uma gaveta começa redonda e se quadra conforme cresce" },
      { type: "section", text: "Gavetas", when: LIQUID_ON, hide: true },
      { type: "toggle", key: "liquid.drawers.dashboard", when: LIQUID_ON, hide: true, label: "Painel" },
      { type: "toggle", key: "liquid.drawers.launcher", when: LIQUID_ON, hide: true, label: "Iniciador", subtext: "E a prévia da área de transferência ao lado" },
      { type: "toggle", key: "liquid.drawers.popouts", when: LIQUID_ON, hide: true, label: "Pop-ups do bar" },
      { type: "toggle", key: "liquid.drawers.sidebar", when: LIQUID_ON, hide: true, label: "Barra lateral", subtext: "A mola e o pescoço; mantém a forma, compartilhada com os utilitários" },
      { type: "toggle", key: "liquid.drawers.utilities", when: LIQUID_ON, hide: true, label: "Utilitários" },
      { type: "toggle", key: "liquid.drawers.session", when: LIQUID_ON, hide: true, label: "Menu da sessão" },
      { type: "toggle", key: "liquid.drawers.osd", when: LIQUID_ON, hide: true, label: "OSD" },
      { type: "toggle", key: "liquid.drawers.settings", when: LIQUID_ON, hide: true, label: "Configurações" },
      { type: "toggle", key: "liquid.drawers.overview", when: LIQUID_ON, hide: true, label: "Visão geral" },
      { type: "section", text: "Desprender", when: LIQUID_ON, hide: true },
      { type: "toggle", key: "liquid.detach.neckBreak", when: LIQUID_ON, hide: true, label: "Rompimento do pescoço", subtext: "O painel de informações da janela e as Configurações ficam unidos ao bar por um fio que estica e se rompe" },
      { type: "toggle", key: "liquid.detach.ripples", when: [LIQUID_ON, { key: "liquid.detach.neckBreak", value: true }], hide: true, label: "Ondulações", subtext: "Duas ondulações percorrem o bar onde ele se rompeu" },
      { type: "toggle", key: "liquid.detach.stray", when: [LIQUID_ON, { key: "liquid.detach.neckBreak", value: true }], hide: true, label: "Gota perdida", subtext: "Uma pequena gota fica pendurada por um instante" }
    ]
  },
  {
    id: "network", label: "Rede", icon: "wifi", category: "connectivity",
    description: "Wi-Fi, ethernet",
    rows: [ { type: "custom", comp: "network" } ]
  },
  {
    // Caelestia's nexus has a "Display" stub (PageRegistry, TODO); this is Omacale's.
    id: "display", label: "Tela", icon: "monitor", category: "connectivity",
    description: "Arranjo, brilho, perfis, luz noturna",
    // The screens and the selected one; the rest is on the sub-pages below
    // (display*), each reached from a row on the page.
    rows: [ { type: "custom", comp: "display" } ]
  },
  {
    id: "bluetooth", label: "Dispositivos conectados", icon: "devices_other", noFill: true, category: "connectivity",
    description: "Bluetooth, pareamento",
    rows: [ { type: "custom", comp: "bluetooth" } ]
  },
  {
    id: "audio", label: "Áudio", icon: "volume_up", category: "connectivity",
    description: "Volumes dos apps, dispositivos de som",
    rows: [ { type: "custom", comp: "audio" } ]
  },
  {
    id: "panels", label: "Painéis", icon: "dock_to_bottom", category: "shell",
    description: "Painel, barra de tarefas, iniciador, barra lateral",
    rows: [
      { type: "nav", icon: "dashboard", label: "Painel", page: "dashboard", status: "dashboard.enabled" },
      { type: "nav", icon: "dock_to_bottom", label: "Barra de tarefas", page: "taskbar", status: "bar" },
      { type: "nav", icon: "apps", label: "Iniciador", page: "launcher", status: "launcher.enabled" },
      { type: "nav", icon: "dock_to_right", label: "Barra lateral", page: "sidebar", status: "sidebar.enabled" },
      { type: "nav", icon: "construction", label: "Utilitários", page: "utilities", status: "utilities.enabled" },
      { type: "nav", icon: "grid_view", label: "Visão geral", page: "overview", status: "overview.enabled" },
      { type: "nav", icon: "power_settings_new", label: "Sessão", page: "session", status: "session.enabled" },
      { type: "nav", icon: "lock", label: "Tela de bloqueio", page: "lock", status: "lock.enabled" },
      { type: "nav", icon: "volume_up", label: "OSD", page: "osd", status: "osd.enabled" },
      { type: "nav", icon: "wallpaper", label: "Área de trabalho", page: "desktop", subtext: "Relógio e visualizador de áudio no papel de parede" }
    ]
  },
  {
    id: "apps", label: "Apps", icon: "apps", category: "shell",
    description: "Apps padrão, favoritos, apps ocultos",
    rows: [ { type: "custom", comp: "apps" } ]
  },
  {
    id: "plugins", label: "Plugins", icon: "extension", category: "shell",
    description: "Plugins do Omarchy nativos e de terceiros",
    rows: [ { type: "custom", comp: "plugins" } ]
  },
  {
    id: "services", label: "Serviços", icon: "settings_suggest", category: "shell",
    description: "Notificações, intervalos de atualização, passos de rolagem",
    rows: [
      { type: "section", text: "Notificações" },
      { type: "nav", icon: "notifications", label: "Notificações", subtext: "Agrupamento na barra lateral", page: "notifications" },
      { type: "section", text: "Atualização" },
      { type: "stepper", key: "services.mediaUpdateInterval", label: "Atualização de mídia", subtext: "Com que frequência a posição da mídia é atualizada (ms)", from: 100, to: 2000, step: 50 },
      { type: "stepper", key: "services.resourceUpdateInterval", label: "Atualização das estatísticas do sistema", subtext: "Intervalo de atualização de CPU, memória e GPU (ms)", from: 500, to: 10000, step: 500 },
      { type: "section", text: "Incrementos de entrada" },
      { type: "stepper", key: "services.volumeStep", label: "Passo do volume", subtext: "Quanto o volume muda por rolagem (%)", from: 1, to: 50, step: 1 },
      { type: "section", text: "Ajuste dos serviços" },
      { type: "stepper", key: "services.visualiserBars", label: "Barras do visualizador", subtext: "Número de barras nos visualizadores de áudio", from: 10, to: 120, step: 2 }
    ]
  },
  {
    id: "region", label: "Idioma e região", icon: "globe", category: "shell",
    description: "Formato do relógio, local do clima, unidades",
    rows: [
      { type: "section", text: "Relógio" },
      { type: "toggle", key: "general.clock24", invert: true, label: "Relógio de 12 horas", subtext: "AM/PM em todo lugar: bar, painel, clima, notificações, manter acordado, gravações" },
      { type: "section", text: "Clima" },
      { type: "text", key: "general.weatherLocation", label: "Local", subtext: "Nome da cidade; vazio detecta pelo seu IP", placeholder: "City" },
      { type: "select", key: "general.units", label: "Unidades", subtext: "Unidades de temperatura", options: [
        { value: "metric", label: "Celsius", icon: "thermometer" },
        { value: "imperial", label: "Fahrenheit", icon: "thermostat" }
      ] }
    ]
  },
  {
    id: "keybinds", label: "Atalhos", icon: "keyboard", category: "system",
    description: "Atalhos no estilo Omarchy para copiar",
    rows: [ { type: "custom", comp: "keybinds" } ]
  },
  {
    id: "looknfeel", label: "Aparência", icon: "auto_awesome", category: "system",
    description: "Estilo do Hyprland do Caelestia para carregar",
    rows: [ { type: "custom", comp: "looknfeel" } ]
  },
  {
    id: "about", label: "Sobre", icon: "info", category: "about",
    description: "Omacale, sistema, redefinir",
    rows: [ { type: "custom", comp: "about" } ]
  }
]

var subpages = {
  // ---- Settings › Display's sub-pages (pages/Display*.qml); every display
  // setting lives here, other pages link to them.
  displayProfiles: { title: "Perfis", rows: [
    { type: "custom", comp: "displayProfiles" },
    { type: "section", text: "Conectar uma tela" },
    { type: "toggle", key: "display.quickOnConnect", label: "Perguntar o que fazer", subtext: "Estender / Espelhar / Somente laptop / Somente externa ao conectar uma tela (também a tecla opcional de tela, Configurações › Atalhos)" }
  ] },
  displayWorkspaces: { title: "Áreas de trabalho", rows: [ { type: "custom", comp: "displayWorkspaces" } ] },
  displayBrightness: { title: "Brilho", rows: [
    { type: "custom", comp: "displayBrightnessList" },
    { type: "section", text: "Juntas" },
    { type: "toggle", key: "display.linkBrightness", label: "Mesmo brilho em todas as telas", subtext: "Um controle e a rolagem do bar movem todas as telas; as teclas de brilho também, com seus atalhos opcionais (Configurações › Atalhos)" },
    { type: "section", text: "Rolagem no bar" },
    { type: "toggle", key: "bar.scroll.brightness", label: "Rolar para mudar o brilho", subtext: "A metade inferior do bar muda o brilho da tela em que está" },
    { type: "stepper", key: "services.brightnessStep", label: "Passo do brilho", subtext: "Quanto uma rolagem muda (%)", from: 1, to: 50, step: 1 }
  ] },
  displayNight: { title: "Luz noturna", rows: [
    { type: "custom", comp: "displayNight" },
    { type: "section", text: "Agenda" },
    { type: "select", key: "display.nightSchedule", label: "Agenda", icon: "schedule", subtext: "Alternar manualmente vale até a próxima mudança da agenda", options: [
      { value: "off", label: "Desligado", icon: "block" }, { value: "sun", label: "Do pôr do sol ao nascer do sol", icon: "wb_twilight" }, { value: "custom", label: "Horários personalizados", icon: "schedule" }
    ] },
    { type: "select", key: "display.nightFrom", when: { key: "display.nightSchedule", value: "custom" }, label: "De", icon: "bedtime", options: halfHours() },
    { type: "select", key: "display.nightTo", when: { key: "display.nightSchedule", value: "custom" }, label: "Até", icon: "wb_sunny", options: halfHours() }
  ] },
  displayShell: { title: "Shell em cada tela", rows: [
    { type: "section", text: "Barra de tarefas" },
    { type: "custom", comp: "screens", mode: "bar" },
    { type: "section", text: "Relógio e visualizador da área de trabalho" },
    { type: "custom", comp: "screens", mode: "desktop" },
    { type: "section", text: "Pop-ups" },
    { type: "custom", comp: "screenSelect", key: "notifs.screen", label: "Notificações", subtext: "Quais telas mostram os pop-ups de notificação" },
    { type: "custom", comp: "screenSelect", key: "osd.screen", when: { key: "osd.enabled", value: true }, label: "Controles do OSD", subtext: "Quais telas mostram os controles de volume e brilho" }
  ] },
  displayText: { title: "Texto e cursor", rows: [
    { type: "custom", comp: "displayTextSize" },
    { type: "section", text: "Cursor" },
    // Real cursor theme sizes; a stepper from 0 started at an unusable 4px.
    { type: "select", key: "display.cursorSize", label: "Tamanho do cursor", subtext: "O Hyprland o desenha neste tamanho vezes a escala de cada tela, então fica igual em todas; apps já abertos mantêm o tamanho antigo até reiniciar", options: [
      { value: "0", label: "Do Omarchy", icon: "arrow_selector_tool" },
      { value: "16", label: "16 px", icon: "arrow_selector_tool" },
      { value: "20", label: "20 px", icon: "arrow_selector_tool" },
      { value: "24", label: "24 px", icon: "arrow_selector_tool" },
      { value: "32", label: "32 px", icon: "arrow_selector_tool" },
      { value: "40", label: "40 px", icon: "arrow_selector_tool" },
      { value: "48", label: "48 px", icon: "arrow_selector_tool" },
      { value: "64", label: "64 px", icon: "arrow_selector_tool" }
    ] },
    { type: "select", key: "display.zeroScaling", label: "Escala de apps X11", subtext: "A escala zero mantém apps X11 nítidos, mas pequenos em telas escaladas. Precisa do omacale.lua carregado; linhas depois dele no looknfeel.lua vencem", options: [
      { value: "auto", label: "Deixar como está", icon: "sync_alt" },
      { value: "on", label: "Escala zero (nítido)", icon: "texture" },
      { value: "off", label: "Escalado (borrado, tamanho certo)", icon: "zoom_in" }
    ] }
  ] },
  wallpapers: { title: "Papéis de parede", rows: [ { type: "custom", comp: "wallpapers" } ] },
  themes: { title: "Temas", rows: [ { type: "custom", comp: "wallpapers", themes: true } ] },
  allApps: { title: "Todos os apps", rows: [ { type: "custom", comp: "allApps" } ] },
  taskbarAppPicker: { title: "Escolher apps", rows: [ { type: "custom", comp: "taskbarAppPicker" } ] },
  appInfo: { title: "Informações do app", rows: [ { type: "custom", comp: "appInfo" } ] },
  pluginInfo: { title: "Plugin", rows: [ { type: "custom", comp: "pluginInfo" } ] },
  notifications: {
    title: "Notificações",
    rows: [
      { type: "section", text: "Pop-ups" },
      { type: "custom", comp: "notifs" },
      { type: "nav", icon: "monitor", label: "Telas", subtext: "Quais telas mostram os pop-ups: em Tela › Shell em cada tela", page: "displayShell" },
      { type: "toggle", key: "notifs.popups.enabled", label: "Mostrar pop-ups", subtext: "Desenhar as notificações que chegam como avisos no estilo Caelestia, sobre tudo, inclusive janelas em tela cheia. Desligado, o Omarchy desenha os seus" },
      { type: "slider", key: "notifs.popups.width", label: "Largura do pop-up (na escala 100%)", icon: "notifications", from: 320, to: 600, step: 10, unit: "px" },
      { type: "section", text: "Avisos" },
      { type: "stepper", key: "utilities.maxToasts", label: "Avisos exibidos", subtext: "Avisos pequenos no canto dos utilitários; os demais esperam a vez", from: 1, to: 10, step: 1 },
      { type: "toggle", key: "utilities.toasts.chargingChanged", label: "Mudanças do carregador", subtext: "Quando o carregador é conectado ou desconectado" },
      { type: "toggle", key: "utilities.toasts.gameModeChanged", label: "Mudanças do modo jogo" },
      { type: "toggle", key: "utilities.toasts.dndChanged", label: "Mudanças do não perturbe" },
      { type: "toggle", key: "utilities.toasts.audioOutputChanged", label: "Mudanças na saída de áudio", subtext: "O dispositivo em que o som toca agora" },
      { type: "toggle", key: "utilities.toasts.audioInputChanged", label: "Mudanças na entrada de áudio", subtext: "O microfone em uso agora" },
      { type: "toggle", key: "utilities.toasts.nowPlaying", label: "Tocando agora", subtext: "A faixa sempre que muda" },
      { type: "section", text: "Notificações" },
      { type: "toggle", key: "notifs.openExpanded", label: "Abrir expandido", subtext: "Mostrar grupos de notificações e pop-ups expandidos por padrão" },
      { type: "stepper", key: "notifs.groupPreviewNum", label: "Quantidade na prévia do grupo", subtext: "Notificações mostradas por grupo antes de recolher", from: 1, to: 10, step: 1 }
    ]
  },
  networkDetail: { title: "Detalhes da rede", rows: [ { type: "custom", comp: "networkDetail" } ] },
  btPair: { title: "Parear novo dispositivo", rows: [ { type: "custom", comp: "btPair" } ] },
  btDevice: { title: "Dispositivo", rows: [ { type: "custom", comp: "btDevice" } ] },
  appVolumes: { title: "Volumes dos apps", rows: [ { type: "custom", comp: "appVolumes" } ] },
  taskbar: {
    title: "Barra de tarefas",
    rows: [
      { type: "section", text: "Comportamento" },
      { type: "select", key: "bar.position", label: "Posição", subtext: "Em qual borda da tela o bar fica. O Omarchy segue Estilo › Bar › Posição", options: [
        { value: "left", label: "Esquerda", icon: "align_horizontal_left" },
        { value: "right", label: "Direita", icon: "align_horizontal_right" },
        { value: "top", label: "Topo", icon: "vertical_align_top" },
        { value: "bottom", label: "Base", icon: "vertical_align_bottom" },
        { value: "omarchy", label: "Omarchy", icon: "sync_alt" }
      ] },
      { type: "toggle", key: "bar.persistent", label: "Persistente", subtext: "Manter o bar visível o tempo todo" },
      { type: "toggle", key: "bar.showOnHover", label: "Mostrar ao passar o mouse", subtext: "Revelar o bar quando o cursor chega à borda" },
      { type: "nav", icon: "monitor", label: "Telas", subtext: "Quais telas têm bar, e a borda de cada uma: em Tela › Shell em cada tela", page: "displayShell" },
      // Everything in the bar, in one list per section: Omacale's items,
      // Omarchy's widgets and plugins alike (pages/LayoutPage.qml). Each row's
      // gear opens its own page below.
      { type: "nav", icon: "apps", label: "Apps", subtext: "Dock opcional: apps fixados, grupos e pastas", page: "taskbarApps", status: "bar.apps.enabled" },
      { type: "section", text: "Bar" },
      { type: "custom", comp: "barLayout" },
      { type: "section", text: "Ações de rolagem" },
      { type: "toggle", key: "bar.scroll.workspaces", label: "Áreas de trabalho", subtext: "Rolar sobre o indicador de áreas de trabalho para trocar de área" },
      { type: "toggle", key: "bar.scroll.volume", label: "Volume", subtext: "Rolar na metade superior do bar para ajustar o volume" },
      { type: "nav", icon: "brightness_6", label: "Brilho", subtext: "Rolagem na metade inferior, e seu passo: em Tela › Brilho", page: "displayBrightness" }
    ]
  },
  taskbarApps: {
    title: "Apps da barra de tarefas",
    rows: [
      { type: "toggle", key: "bar.apps.enabled", label: "Mostrar apps na barra de tarefas", subtext: "Desligado por padrão. Um dock dentro do bar, em qualquer borda da tela" },
      { type: "toggle", key: "bar.apps.showRunning", label: "Mostrar apps em execução", subtext: "Incluir apps não fixados. Clique para focar ou alternar janelas; clique do meio abre uma nova instância", when: { key: "bar.apps.enabled", value: true } },
      { type: "toggle", key: "bar.apps.useAvailableSpace", label: "Usar o espaço disponível", subtext: "Crescer para caber os apps, mantendo o relógio, a bandeja e outros controles do bar acessíveis", when: { key: "bar.apps.enabled", value: true } },
      { type: "stepper", key: "bar.apps.maxShown", label: "Espaços visíveis", subtext: "Comprimento máximo; role para ver mais em um bar cheio", from: 1, to: 100, step: 1, when: [{ key: "bar.apps.enabled", value: true }, { key: "bar.apps.useAvailableSpace", value: false }], hide: true },
      { type: "toggle", key: "bar.apps.showSettings", label: "Mostrar botão de configurações", subtext: "Atalho opcional; esta página está sempre disponível nas configurações da barra de tarefas", when: { key: "bar.apps.enabled", value: true } },
      { type: "custom", comp: "taskbarApps" }
    ]
  },
  workspaces: {
    title: "Áreas de trabalho",
    rows: [
      { type: "stepper", key: "bar.workspaces.shown", label: "Exibidas", subtext: "Número de áreas de trabalho exibidas", from: 1, to: 10, step: 1 },
      { type: "select", key: "bar.workspaces.display", label: "Tela", subtext: "Como cada área de trabalho é desenhada", options: [
        { value: "shapes", label: "Formas", icon: "category" },
        { value: "numbers", label: "Números", icon: "pin" }
      ] },
      { type: "toggle", key: "bar.workspaces.activeIndicator", label: "Indicador ativo" },
      { type: "toggle", key: "bar.workspaces.activeTrail", label: "Rastro ativo", subtext: "A borda final do indicador fica para trás" },
      { type: "toggle", key: "bar.workspaces.occupiedBg", label: "Fundo ocupado", subtext: "Destacar sequências de áreas de trabalho ocupadas" },
      { type: "toggle", key: "bar.workspaces.showWindows", label: "Mostrar janelas", subtext: "Mostrar ícones das janelas abertas em cada área de trabalho" },
      { type: "stepper", key: "bar.workspaces.maxWindowIcons", label: "Máximo de ícones de janelas", from: 0, to: 10, step: 1 },
      { type: "section", text: "Áreas de trabalho especiais" },
      { type: "select", key: "bar.workspaces.specialDisplay", label: "Tela", subtext: "Como o rascunho e outras áreas especiais são desenhados enquanto uma está aberta", options: [
        { value: "icons", label: "Ícones", icon: "star" },
        { value: "star", label: "Somente estrela", icon: "grade" },
        { value: "letters", label: "Letras", icon: "text_fields" },
        { value: "shapes", label: "Formas", icon: "category" }
      ] },
      { type: "toggle", key: "bar.workspaces.specialShowWindows", label: "Mostrar janelas", subtext: "Mostrar ícones das janelas abertas em cada área especial" }
    ]
  },
  overview: {
    title: "Visão geral",
    rows: [
      { type: "toggle", key: "overview.enabled", label: "Ativado", subtext: "Uma grade das áreas de trabalho deste monitor, com prévias ao vivo das janelas. Vincule em Configurações › Atalhos" },
      { type: "select", key: "overview.position", label: "Posição", subtext: "Flutuar no meio da tela, ou crescer a partir da borda superior ou inferior", options: [
        { value: "top", label: "Topo", icon: "vertical_align_top" },
        { value: "middle", label: "Meio", icon: "vertical_align_center" },
        { value: "bottom", label: "Base", icon: "vertical_align_bottom" }
      ] },
      { type: "toggle", key: "overview.detached", label: "Desprendido", subtext: "No topo ou na base, flutuar um pouco afastado da borda como na posição do meio, em vez de crescer a partir da moldura" },
      { type: "slider", key: "overview.gap", when: { key: "overview.detached", value: true }, label: "Distância do desprendido", icon: "height", from: 0, to: 200, step: 4, unit: "px" },
      { type: "section", text: "Grade" },
      { type: "stepper", key: "overview.rows", label: "Linhas", from: 1, to: 6, step: 1 },
      { type: "stepper", key: "overview.columns", label: "Colunas", from: 1, to: 10, step: 1 },
      { type: "toggle", key: "overview.hideEmptyRows", label: "Ocultar linhas vazias", subtext: "Desenhar apenas linhas com uma janela ou a área de trabalho ativa" },
      { type: "slider", key: "overview.scale", label: "Tamanho do bloco", icon: "grid_view", from: 0.08, to: 0.3, step: 0.01, unit: "%" },
      { type: "section", text: "Janelas" },
      { type: "toggle", key: "overview.previews", label: "Prévias ao vivo", subtext: "Desenhar a superfície de cada janela em seu bloco" },
      { type: "toggle", key: "overview.showIcons", label: "Ícones dos apps", subtext: "Mostrar o ícone do app sobre cada janela" }
    ]
  },
  activeWindow: {
    title: "Janela ativa",
    rows: [
      { type: "toggle", key: "bar.activeWindow.enabled", label: "Mostrar título", subtext: "Título da janela girado no meio do bar" },
      { type: "toggle", key: "bar.activeWindow.compact", label: "Compacto", subtext: "Mostrar apenas a última parte de títulos como 'Página — Navegador'" },
      { type: "toggle", key: "bar.popouts.activeWindow", label: "Pop-up ao passar o mouse", subtext: "Mostrar uma prévia ao vivo da janela ao passar o mouse" }
    ]
  },
  tray: {
    title: "Bandeja",
    rows: [
      { type: "toggle", key: "bar.tray.enabled", label: "Mostrar bandeja" },
      { type: "toggle", key: "bar.tray.background", label: "Fundo", subtext: "Desenhar uma pílula atrás da bandeja" },
      { type: "toggle", key: "bar.tray.recolour", label: "Recolorir ícones", subtext: "Tingir os ícones da bandeja com o esquema" },
      { type: "toggle", key: "bar.tray.compact", label: "Sempre compacta", subtext: "Manter a bandeja atrás de uma seta que abre ao passar o mouse. Desligado, ela ainda recolhe sozinha quando o bar fica sem espaço" },
      { type: "toggle", key: "bar.tray.cascade", label: "Cascata", subtext: "Empilhar os ícones como um baralho; ao passar o mouse, eles se abrem em leque" },
      { type: "toggle", key: "bar.popouts.tray", label: "Pop-up ao passar o mouse", subtext: "Mostrar o menu da bandeja ao passar o mouse sobre um ícone" },
      { type: "section", text: "Ícones" },
      { type: "custom", comp: "trayIcons" }
    ]
  },
  barButtons: {
    title: "Logo e desligar",
    rows: [
      { type: "toggle", key: "bar.logo", label: "Logo", subtext: "Ícone no início do bar; clique abre o iniciador" },
      { type: "custom", comp: "logoPicker" },
      { type: "toggle", key: "bar.power", label: "Botão de desligar", subtext: "Abre o menu da sessão" }
    ]
  },
  status: {
    title: "Ícones de status",
    rows: [
      { type: "section", text: "Ícones visíveis" },
      { type: "toggle", key: "bar.status.lockStatus", label: "Caps / Num Lock", subtext: "Mostrado apenas enquanto uma tecla de trava está ativa" },
      { type: "toggle", key: "bar.status.audio", label: "Áudio" },
      { type: "toggle", key: "bar.status.microphone", label: "Microfone" },
      { type: "toggle", key: "bar.status.microphoneInUseOnly", label: "Microfone apenas durante a gravação", subtext: "Ocultá-lo até um app abrir o microfone" },
      { type: "toggle", key: "bar.status.kbLayout", label: "Layout do teclado", subtext: "Código do layout ativo; passe o mouse para trocar de layout" },
      { type: "toggle", key: "bar.status.network", label: "Rede" },
      { type: "toggle", key: "bar.status.bluetooth", label: "Bluetooth" },
      { type: "toggle", key: "bar.status.bluetoothConnectedOnly", label: "Bluetooth apenas quando conectado", subtext: "Ocultar o ícone de Bluetooth inativo" },
      { type: "toggle", key: "bar.status.battery", label: "Bateria / perfil de energia" },
      { type: "toggle", key: "bar.status.keepAwake", label: "Manter acordado", subtext: "Ícone de café enquanto o manter acordado está ligado" },
      { type: "toggle", key: "bar.status.update", label: "Atualizações do Omarchy", subtext: "Mostrado enquanto há uma atualização do Omarchy pendente; clique executa omarchy update" },
      { type: "toggle", key: "bar.status.notifications", label: "Notificações", subtext: "Contagem de não lidas e estado do não perturbe; clique abre a barra lateral" },
      { type: "section", text: "Comportamento" },
      { type: "toggle", key: "bar.popouts.statusIcons", label: "Pop-up ao passar o mouse", subtext: "Mostrar um pop-up de detalhes ao passar o mouse sobre os ícones de status" }
    ]
  },
  clock: {
    title: "Relógio",
    rows: [
      { type: "toggle", key: "bar.clock.enabled", label: "Mostrar relógio", subtext: "Desligue para remover o relógio (e a hora) do bar por completo" },
      { type: "toggle", key: "bar.clock.background", when: { key: "bar.clock.enabled", value: true }, label: "Fundo" },
      { type: "toggle", key: "bar.clock.showDate", when: { key: "bar.clock.enabled", value: true }, label: "Mostrar data" },
      { type: "toggle", key: "bar.clock.showIcon", when: { key: "bar.clock.enabled", value: true }, label: "Mostrar ícone" },
      { type: "toggle", key: "bar.clock.showSeconds", when: { key: "bar.clock.enabled", value: true }, label: "Mostrar segundos" }
    ]
  },
  dashboard: {
    title: "Painel",
    rows: [
      { type: "section", text: "Geral" },
      { type: "toggle", key: "dashboard.enabled", label: "Ativado" },
      { type: "toggle", key: "dashboard.showOnHover", label: "Mostrar ao passar o mouse", subtext: "Revelar quando o cursor chega à borda superior" },
      { type: "toggle", key: "dashboard.clockSeconds", label: "Mostrar segundos no relógio", subtext: "Exibir segundos no relógio do painel principal" },
      { type: "toggle", key: "dashboard.mediaGif", label: "Gato bongo", subtext: "Dançar enquanto a mídia toca" },
      { type: "section", text: "Mídia" },
      { type: "toggle", key: "dashboard.lyrics", label: "Letras", subtext: "Letras sincronizadas do lrclib.net" },
      { type: "toggle", key: "dashboard.visualiser", label: "Visualizador", subtext: "Barras de áudio ao redor da capa (precisa do cava)" },
      { type: "section", text: "Abas" },
      { type: "toggle", key: "dashboard.tabs.dashboard", label: "Painel" },
      { type: "toggle", key: "dashboard.tabs.media", label: "Mídia" },
      { type: "toggle", key: "dashboard.tabs.performance", label: "Desempenho" },
      { type: "toggle", key: "dashboard.tabs.weather", label: "Clima" },
      { type: "section", text: "Widgets de desempenho" },
      { type: "toggle", key: "dashboard.performance.showBattery", label: "Bateria" },
      { type: "toggle", key: "dashboard.performance.showGpu", label: "GPU" },
      { type: "toggle", key: "dashboard.performance.showCpu", label: "CPU" },
      { type: "toggle", key: "dashboard.performance.showMemory", label: "Memória" },
      { type: "toggle", key: "dashboard.performance.showStorage", label: "Armazenamento" },
      { type: "toggle", key: "dashboard.performance.showNetwork", label: "Rede" }
    ]
  },
  launcher: {
    title: "Iniciador",
    rows: [
      { type: "section", text: "Geral" },
      { type: "toggle", key: "launcher.enabled", label: "Ativado" },
      { type: "text", key: "launcher.actionPrefix", label: "Prefixo de ação", subtext: "Prefixo usado para executar ações no iniciador", placeholder: "Prefix" },
      { type: "text", key: "launcher.menuPrefix", label: "Prefixo do menu", subtext: "Prefixo que abre o menu do Omarchy no iniciador", placeholder: "Prefix" },
      { type: "section", text: "Tela" },
      { type: "stepper", key: "launcher.maxShown", label: "Máximo de itens exibidos", from: 3, to: 12, step: 1 },
      { type: "stepper", key: "launcher.maxWallpapers", label: "Máximo de papéis de parede exibidos", subtext: "Tamanho do carrossel para \">wallpaper\" e \">theme\"", from: 1, to: 15, step: 2 },
      { type: "stepper", key: "launcher.dragThreshold", label: "Limite de arrasto", subtext: "Pixels arrastados da borda inferior antes de abrir", from: 10, to: 200, step: 5 },
      { type: "section", text: "Comportamento" },
      { type: "toggle", key: "launcher.vimKeybinds", label: "Atalhos Vim", subtext: "Navegar pelos resultados com Ctrl+J / Ctrl+K" },
      { type: "toggle", key: "launcher.dangerousActions", label: "Ativar ações perigosas", subtext: "Permitir ações que desligam ou encerram a sessão" }
    ]
  },
  session: {
    title: "Sessão",
    rows: [
      { type: "toggle", key: "session.enabled", label: "Ativado" },
      { type: "select", key: "session.menu", label: "Menu", subtext: "O que a tecla de sessão abre (Configurações › Atalhos tem os atalhos opcionais Super+Esc e da tecla de energia)", options: [
        { value: "omacale", label: "Sessão do Omacale", icon: "power_settings_new" },
        { value: "omarchy", label: "Menu do Omarchy", icon: "menu" }
      ] },
      { type: "select", key: "session.extraStyle", label: "Estilo do bloqueio e protetor de tela", subtext: "Bloquear e Protetor de tela oferecem tudo o que o menu Sistema do Omarchy oferece: como dois botões pequenos lado a lado, ou em tamanho normal como os outros", options: [
        { value: "compact", label: "Compacto", icon: "view_column" },
        { value: "full", label: "Tamanho normal", icon: "crop_square" }
      ] },
      { type: "custom", comp: "sessionPicture", when: { key: "session.gif", value: true } },
      { type: "slider", key: "session.gifSpeed", when: { key: "session.gif", value: true }, label: "Velocidade da animação", icon: "speed", from: 0.1, to: 2, step: 0.05, unit: "x", commit: "release" },
      { type: "toggle", key: "session.vimKeybinds", label: "Atalhos Vim", subtext: "Mover entre botões com Ctrl+J / Ctrl+K" },
      { type: "stepper", key: "session.dragThreshold", label: "Limite de arrasto", subtext: "Pixels arrastados da borda direita antes de abrir", from: 10, to: 200, step: 5 },
      { type: "select", key: "session.sleepAction", label: "Terceiro botão", subtext: "O que o botão de seta para baixo faz. Usa o outro quando o Omarchy diz que o seu não está disponível, e some quando nenhum está", options: [
        { value: "hibernate", label: "Hibernar", icon: "downloading" },
        { value: "suspend", label: "Suspender", icon: "bedtime" }
      ] },
      { type: "section", text: "Botões" },
      { type: "custom", comp: "sessionButtons" },
      { type: "section", text: "Ícones e comandos" },
      { type: "text", key: "session.icons.logout", label: "Ícone de sair", subtext: "Um nome do Material Symbols", placeholder: "logout" },
      { type: "text", key: "session.icons.shutdown", label: "Ícone de desligar", placeholder: "power_settings_new" },
      { type: "text", key: "session.icons.hibernate", label: "Ícone de repouso", placeholder: "follows the third button" },
      { type: "text", key: "session.icons.reboot", label: "Ícone de reiniciar", placeholder: "cached" },
      { type: "text", key: "session.icons.lock", label: "Ícone de bloquear", placeholder: "lock" },
      { type: "text", key: "session.icons.screensaver", label: "Ícone do protetor de tela", placeholder: "slideshow" },
      { type: "text", key: "session.commands.logout", label: "Comando de sair", subtext: "Vazio executa o do Omarchy", placeholder: "omarchy system logout" },
      { type: "text", key: "session.commands.shutdown", label: "Comando de desligar", placeholder: "omarchy system shutdown" },
      { type: "text", key: "session.commands.hibernate", label: "Comando de repouso", subtext: "Definido, ele sempre roda como está", placeholder: "Omarchy's suspend / hibernate" },
      { type: "text", key: "session.commands.reboot", label: "Comando de reiniciar", placeholder: "omarchy system reboot" },
      { type: "text", key: "session.commands.lock", label: "Comando de bloquear", placeholder: "omarchy-system-lock" },
      { type: "text", key: "session.commands.screensaver", label: "Comando do protetor de tela", placeholder: "omarchy-launch-screensaver force" }
    ]
  },
  lock: {
    title: "Tela de bloqueio",
    rows: [
      { type: "toggle", key: "lock.enabled", label: "Tela de bloqueio do Omacale", subtext: "Desenhar a tela de bloqueio do Omarchy como o Caelestia; o Omarchy mantém o bloqueio da sessão e a verificação de senha" },
      { type: "custom", comp: "lock" },
      { type: "section", text: "Cartões" },
      { type: "toggle", key: "lock.weather", when: { key: "lock.enabled", value: true }, label: "Clima", subtext: "Condições, temperatura e máxima e mínima de hoje" },
      { type: "toggle", key: "lock.fetch", when: { key: "lock.enabled", value: true }, label: "Fetch", subtext: "Tempo ligado, sessão e bateria ao lado do logo" },
      { type: "toggle", key: "lock.media", when: { key: "lock.enabled", value: true }, label: "Mídia", subtext: "O que está tocando, com avançar e pausar" },
      { type: "toggle", key: "lock.resources", when: { key: "lock.enabled", value: true }, label: "Recursos", subtext: "CPU, memória e disco" },
      { type: "toggle", key: "lock.notifs", when: { key: "lock.enabled", value: true }, label: "Notificações", subtext: "O dock de notificações, agrupado como na barra lateral" },
      { type: "section", text: "Privacidade" },
      { type: "toggle", key: "lock.hideNotifs", when: { key: "lock.enabled", value: true }, label: "Ocultar o conteúdo das notificações", subtext: "Mostrar \"Desbloqueie para ver as notificações\" em vez das notificações" },
      { type: "toggle", key: "lock.revealPassword", when: { key: "lock.enabled", value: true }, label: "Mostrar botão de senha", subtext: "Permitir que o ícone no campo de senha mostre os caracteres digitados" },
      { type: "section", text: "Tela" },
      { type: "select", key: "lock.blankAfter", when: { key: "lock.enabled", value: true }, label: "Tela desliga após bloquear", subtext: "Quanto tempo a tela bloqueada fica acesa ociosa antes de apagar. Nunca mantém o painel ligado até desbloquear (desgaste e consumo)", options: [
        { value: "5", label: "5 segundos" },
        { value: "15", label: "15 segundos" },
        { value: "30", label: "30 segundos" },
        { value: "60", label: "1 minuto" },
        { value: "300", label: "5 minutos" },
        { value: "0", label: "Nunca" }
      ] },
      { type: "section", text: "Aparência" },
      { type: "toggle", key: "lock.useWallpaper", when: { key: "lock.enabled", value: true }, label: "Usar o papel de parede", subtext: "Mostrar o papel de parede atrás do bloqueio em vez de uma cópia desfocada da tela" },
      { type: "toggle", key: "lock.blur", when: { key: "lock.enabled", value: true }, label: "Desfocar o papel de parede", subtext: "Desfocar o papel de parede atrás do cartão de bloqueio; a cópia da tela é sempre desfocada" },
      { type: "toggle", key: "lock.recolourLogo", when: { key: "lock.enabled", value: true }, label: "Recolorir o logo", subtext: "Tingir o logo do cartão fetch com o esquema" }
    ]
  },
  // Caelestia osdconfig.hpp; Caelestia has no Nexus page for it.
  osd: {
    title: "OSD",
    rows: [
      { type: "toggle", key: "osd.enabled", label: "OSD do Omacale", subtext: "Os controles do Caelestia saindo da borda da moldura, e avisos para todos os outros OSD do Omarchy" },
      { type: "custom", comp: "osd" },
      { type: "nav", icon: "monitor", label: "Telas", subtext: "Quais telas mostram os controles: em Tela › Shell em cada tela", page: "displayShell" },
      { type: "section", text: "Controles" },
      { type: "toggle", key: "osd.enableBrightness", when: { key: "osd.enabled", value: true }, label: "Brilho", subtext: "Mostrado quando o Omarchy informa o nível da tela" },
      { type: "toggle", key: "osd.enableMicrophone", when: { key: "osd.enabled", value: true }, label: "Microfone", subtext: "O volume de entrada, e mostrar o OSD quando muda" },
      { type: "stepper", key: "osd.hideDelay", when: { key: "osd.enabled", value: true }, label: "Ocultar após", subtext: "Quanto tempo fica visível após uma mudança (ms)", from: 500, to: 10000, step: 250 },
      { type: "section", text: "Avisos" },
      { type: "toggle", key: "osd.toasts", when: { key: "osd.enabled", value: true }, label: "Outras mensagens do OSD", subtext: "Mídia, microfone, luz do teclado, dispositivos de entrada, energia e o resto como avisos; desligado, o Omarchy desenha" }
    ]
  },
  // Caelestia backgroundconfig.hpp; Caelestia has no Nexus page for it.
  desktop: {
    title: "Área de trabalho",
    rows: [
      { type: "nav", icon: "monitor", label: "Telas", subtext: "Quais telas mostram o relógio e o visualizador: em Tela › Shell em cada tela", page: "displayShell" },
      { type: "section", text: "Relógio da área de trabalho" },
      { type: "toggle", key: "background.desktopClock.enabled", label: "Relógio da área de trabalho", subtext: "Um relógio e data grandes desenhados no papel de parede" },
      { type: "select", key: "background.desktopClock.position", when: { key: "background.desktopClock.enabled", value: true }, label: "Posição", subtext: "Onde o relógio fica na tela", options: [
        { value: "top-left", label: "Superior esquerdo", icon: "north_west" },
        { value: "top-center", label: "Superior central", icon: "north" },
        { value: "top-right", label: "Superior direito", icon: "north_east" },
        { value: "middle-left", label: "Meio esquerdo", icon: "west" },
        { value: "middle-center", label: "Centro", icon: "filter_center_focus" },
        { value: "middle-right", label: "Meio direito", icon: "east" },
        { value: "bottom-left", label: "Inferior esquerdo", icon: "south_west" },
        { value: "bottom-center", label: "Inferior central", icon: "south" },
        { value: "bottom-right", label: "Inferior direito", icon: "south_east" }
      ] },
      { type: "slider", key: "background.desktopClock.scale", when: { key: "background.desktopClock.enabled", value: true }, label: "Escala", icon: "aspect_ratio", from: 0.5, to: 2, step: 0.05, unit: "x" },
      { type: "toggle", key: "background.desktopClock.invertColors", when: { key: "background.desktopClock.enabled", value: true }, label: "Inverter cores", subtext: "Usar as cores do contêiner, para um relógio sobre um papel de parede claro (ou escuro, no modo claro)" },
      { type: "toggle", key: "background.desktopClock.background.enabled", when: { key: "background.desktopClock.enabled", value: true }, label: "Fundo", subtext: "Desenhar o relógio sobre uma placa arredondada" },
      { type: "slider", key: "background.desktopClock.background.opacity", when: { key: "background.desktopClock.background.enabled", value: true }, label: "Opacidade do fundo", icon: "opacity", from: 0, to: 1, step: 0.01, unit: "%" },
      { type: "toggle", key: "background.desktopClock.background.blur", when: { key: "background.desktopClock.background.enabled", value: true }, label: "Desfoque", subtext: "Desfocar o papel de parede atrás da placa" },
      { type: "toggle", key: "background.desktopClock.shadow.enabled", when: { key: "background.desktopClock.enabled", value: true }, label: "Sombra", subtext: "Uma sombra suave sob o relógio" },
      { type: "slider", key: "background.desktopClock.shadow.opacity", when: { key: "background.desktopClock.shadow.enabled", value: true }, label: "Opacidade da sombra", icon: "opacity", from: 0, to: 1, step: 0.01, unit: "%" },
      { type: "slider", key: "background.desktopClock.shadow.blur", when: { key: "background.desktopClock.shadow.enabled", value: true }, label: "Desfoque da sombra", icon: "blur_on", from: 0, to: 1, step: 0.01, unit: "%" },
      { type: "section", text: "Visualizador de áudio" },
      { type: "toggle", key: "background.visualiser.enabled", label: "Visualizador de áudio", subtext: "Barras subindo da base do papel de parede (precisa do cava)" },
      { type: "toggle", key: "background.visualiser.autoHide", when: { key: "background.visualiser.enabled", value: true }, label: "Ocultar automaticamente", subtext: "Mostrar apenas enquanto nenhuma janela em mosaico cobre a área de trabalho" },
      { type: "toggle", key: "background.visualiser.blur", when: { key: "background.visualiser.enabled", value: true }, label: "Desfoque", subtext: "Desfocar o papel de parede atrás das barras" },
      { type: "slider", key: "background.visualiser.rounding", when: { key: "background.visualiser.enabled", value: true }, label: "Arredondamento das barras", icon: "rounded_corner", from: 0, to: 2, step: 0.05, unit: "x" },
      { type: "slider", key: "background.visualiser.spacing", when: { key: "background.visualiser.enabled", value: true }, label: "Espaçamento das barras", icon: "space_bar", from: 0, to: 3, step: 0.05, unit: "x" }
    ]
  },
  sidebar: {
    title: "Barra lateral",
    rows: [
      { type: "section", text: "Geral" },
      { type: "toggle", key: "sidebar.enabled", label: "Ativado", subtext: "Ativar a gaveta de notificações da barra lateral" },
      { type: "slider", key: "sidebar.width", label: "Largura da barra lateral (na escala 100%)", icon: "dock_to_right", from: 320, to: 600, step: 10, unit: "px" }
    ]
  },
  utilities: {
    title: "Utilitários",
    rows: [
      { type: "section", text: "Geral" },
      { type: "toggle", key: "utilities.enabled", label: "Ativado", subtext: "Ativar os ajustes rápidos e a gaveta de utilitários" },
      { type: "slider", key: "utilities.width", label: "Largura dos utilitários (na escala 100%)", icon: "tune", from: 320, to: 600, step: 10, unit: "px" },
      { type: "section", text: "Ajustes rápidos" },
      { type: "toggle", key: "utilities.toggles.wifi", label: "Wi-Fi" },
      { type: "toggle", key: "utilities.toggles.bluetooth", label: "Bluetooth" },
      { type: "toggle", key: "utilities.toggles.mic", label: "Microfone" },
      { type: "toggle", key: "utilities.toggles.settings", label: "Configurações", subtext: "Abre as configurações do Omacale" },
      { type: "toggle", key: "utilities.toggles.gameMode", label: "Modo jogo" },
      { type: "toggle", key: "utilities.toggles.dnd", label: "Não perturbe" },
      { type: "toggle", key: "utilities.toggles.nightlight", label: "Luz noturna", subtext: "A luz noturna do Omarchy; mais de seis alternadores passam para uma segunda linha" }
    ]
  }
}

function pageById(id) {
  for (var i = 0; i < pages.length; i++) if (pages[i].id === id) return pages[i]
  return subpages[id] ? { id: id, label: subpages[id].title, rows: subpages[id].rows, isSub: true } : null
}

// Every searchable row, tagged with where it lives.
function searchRows(query) {
  var q = String(query || "").trim().toLowerCase()
  if (!q) return []
  var out = []
  var add = function(where, rows) {
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i]
      if (r.type === "section" || r.type === "custom" || r.type === "nav") continue
      var hay = (r.label + " " + (r.subtext || "") + " " + where).toLowerCase()
      if (hay.indexOf(q) >= 0) out.push(Object.assign({ where: where }, r))
    }
  }
  for (var p = 0; p < pages.length; p++) add(pages[p].label, pages[p].rows)
  for (var id in subpages) add(subpages[id].title, subpages[id].rows)
  return out
}

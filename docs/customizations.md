# Customizações

Detalhamento técnico do que neste repositório **não** é Omarchy padrão. A
regra do jogo: nada em `/usr/share/omarchy` é editado; tudo aqui sobrepõe
depois que os defaults carregam (a ordem de `require()` no
`hyprland.lua` garante isso) ou substitui caminhos que o Omarchy lê de
`~/.config`.

## Hyprland

### `hypr/bindings.lua` — fluxo de janelas estilo vim

- `SUPER+H/J/K/L` vira foco direcional (`hl.dsp.focus`), substituindo os
  defaults do Omarchy para essas teclas (togglesplit, menu de keybindings,
  ciclo de layout). `SUPER+SHIFT+H/J/K/L` move/troca a janela na direção.
- `SUPER+;` abre o popup de atalhos (`omarchy-menu-keybindings`) para liberar
  o `SUPER+C` como copy universal.
- Lançadores com foco: `SUPER+SHIFT+G` → ZapFast (WhatsApp nativo),
  `SUPER+SHIFT+M` → Limusic, `SUPER+SHIFT+/` → Bitwarden,
  `SUPER+SHIFT+ALT+G` → Signal (herdou o atalho antigo do WhatsApp Web).
- **Waystone (price check de PoE2)**: o app registra atalhos via portal
  GlobalShortcuts, mas o Hyprland com config em Lua não aceita mais
  `hyprctl keyword bind` — o bind dinâmico dele falha em silêncio. O repo
  amarra `ALT+Z` (price check) e `ALT+X` (scan de únicos) com um guard em
  Lua: só dispara se a janela ativa é do jogo (classe contém `exile` ou é
  `steam_app_2694490`, cobrindo XWayland e Wayland nativo conforme o backend
  do Proton). O `Esc` do painel é amarrado dinamicamente nos eventos
  `layer.opened`/`layer.closed` da layer-shell `gtk4-layer-shell`, e removido
  quando ela fecha — sem sequestrar o Esc do resto do sistema.
- **Gravação**: `SUPER+/` salva os últimos 60 s (replay buffer), `SUPER+,`
  inicia/para gravação — ambos dependem do `gsr-replay.service` (abaixo) e
  dos scripts `gsr-clip.sh`/`gsr-record.sh`.
- `SUPER+.` captura a tela cheia para `/data/midia/fotos/screenshots`
  (via `OMASNAP_SCREENSHOT_DIR` em `hyprland.lua`).

### `hypr/looknfeel.lua` — overrides que vencem os defaults

- `MOZ_ENABLE_WAYLAND=0` e `ELECTRON_OZONE_PLATFORM_HINT=x11`: sobrescreve
  `default/hypr/envs.lua` do Omarchy, que força Wayland nativo e quebra dead
  keys (o `looknfeel.lua` carrega por último, então vence). Motivo completo
  em [troubleshooting.md](troubleshooting.md).
- Borda da janela ativa em `rgba(d5e0dd33)` — neutra, tirada do foreground do
  tema Aether, em vez do verde do tema.
- `allow_tearing = true` para jogos fullscreen (latência; monitor sem VRR).

### `hosts/visao/` — overlay da máquina

- `monitors.lua`: `HDMI-A-1` em 1920x1080@75, scale 1, e um monitor genérico
  `preferred/auto` (o "auto" cobre mudanças de display). `GDK_SCALE=1`.
- `autostart.lua`: sobe o Waystone no login.

## Omacale (shell)

O bar padrão do Omarchy é substituído pelo plugin **omacale.bar**
(Caelestia-style, Quickshell). O diretório
`home/.config/omarchy/plugins/omacale.bar/` é uma **cópia modificada** da
versão 0.58.0 upstream (AyushKr2003, GPL-3.0): relógio, tray, lock screen e
traduções foram editados; atualizações upstream precisam ser mescladas à mão
(o script `scripts/upstream-check` dentro do plugin ajuda a detectar
divergência). Ele é linkado como diretório inteiro pelo `link.py`.

### `omarchy/shell.json` — seleção de plugins

- Bar: `omacale.bar`, com relógio `dddd HH:mm` (formato alternativo com
  número da semana), relógios mundiais (São Paulo, Londres, Dubai, Tóquio,
  LA), clima, tray, painel do Superwhisper e indicadores padrão.
- `disabledPlugins`: `omarchy.notifications`, `omarchy.osd`,
  `omarchy.lock` — os três serviços padrão desligados em favor dos clones
  `vz.*`.
- Dock: Nautilus, Chromium, foot, omacalc, omawrite, X, YouTube (base).
- Idle: lock em 15 min, screensaver em 10 min.

### `omacale/settings.json` — preferências do Omacale

Dark + pureBlack, palette Material tonalspot, transparência (base 0.95,
layers 0.85), bar vertical à esquerda com `showOnHover`, workspaces como
formas geométricas (5), dashboard com abas mídia/performance/clima, lock com
wallpaper do tema, night light 4000K (20:00–07:00, agendamento off), clima em
São Paulo, relógio 24h, unidades métricas.

### `omarchy/plugins/vz.lock`, `vz.notifications`, `vz.osd`

Clones dos plugins padrão do Omarchy gerados pelo *handover* do Omacale
(`clonedFrom` nos manifests), **patcheados** para colaborar com o bar:

- `vz.notifications` ganhou IPC `omacale:headless-popups v4`: enquanto o
  Omacale desenha os toasts, o daemon padrão fica headless e responde a
  comandos por card (pause/resume/dismiss/invoke/forget), com health check —
  se o bar não estiver rodando, a surface padrão volta sem restart.
- `vz.osd` ganhou `omacale:osd-handover v4`: volume/mic/brightness viram os
  sliders verticais do Omacale; o resto vira toasts. O handover é condicional
  ao processo, ao OSD ligado e a não-fullscreen.
- Os `.omacale-orig` guardam a versão pré-patch para referência/diff.

Eles ficam versionados porque o lock/notificações/OSD exatos fazem parte do
setup; se o Omacale for reinstalado e regenerar os clones, basta rodar
`python3 scripts/link.py` de novo.

## Temas

- **Aether** (`omarchy/themes/aether/`): paleta gerada pelo Aether a partir
  do wallpaper Fedora 42 *day* — fundo `#130300`, accent `#4a8e64` (verde
  dessaturado), foreground `#D5E0DD`. A pasta é versionada: se o Aether
  regenerar, as mudanças aparecem no repo. O `install.sh` aplica este tema.
- **fedora-42** (`omarchy/themes/fedora-42/`): tema Adwaita-dark após o
  Fedora 42 Workstation, com os wallpapers oficiais (CC-BY-SA 4.0, créditos
  em `CREDITS.md`).
- **Hooks `theme-set.d/`**: `10-owe-sync` pinga o daemon do owe (wallpaper
  engine) a cada troca de tema; `zapfast-theme` copia a paleta gerada
  (`~/.local/state/omarchy/current/theme/zapfast.json`) para
  `~/.config/zapfast/themes/omarchy.json` e roda `zapfast reload-themes` —
  o app retema sem restart. O template usado é
  `omarchy/themed/zapfast.json.tpl` (o `.tpl.sample` de Alacritty é só o
  exemplo upstream).
- **Integrados ao tema**: Ghostty/foot/Alacritty/kitty incluem
  `~/.local/state/omarchy/current/theme/*`; o btop usa um tema
  `current.theme` casado à mão com a paleta Aether.

## Terminais e shell

- **Ghostty** (`ghostty/config`): JetBrainsMono Nerd Font 9, padding 14,
  cursor block sem blink, `async-backend = epoll` (mitiga lentidão geral no
  Hyprland), copiar/colar em `Ctrl/Shift+Insert`, e **encoding CSI-u** para
  `Shift+Enter` (`13;2u`) e `Alt+Shift+Enter` (`13;4u`) — sem isso o tmux não
  distingue M-S-Enter (usado para abrir janelas). O `local.conf` impõe
  fundo `#0d0d0d` depois do tema.
- **foot/Alacritty**: mesmos paddings/fonte/CSI-u; mantidos como terminais
  alternativos já plugados no sistema de temas do Omarchy.
- **fish** (`fish/config.fish`): espelha o init bash do Omarchy — `mise
  activate` e `starship init` — e adiciona `zoxide` (o `z`/`zi` do init bash
  que o espelho não cobria) e `~/.local/bin` no PATH. fish é o login shell.
- **starship.toml**: prompt mínimo — diretório truncado em 2 níveis, branch
  em itálico cyan, status git compacto (`?` untracked, ícone nerd-font para
  modified, `⇡/⇣` ahead/behind), `❯`/`✗` em cyan.

## Neovim (LazyVim)

Base LazyVim (`init.lua` → `config.lazy` + `lsp` + `dap` + `java`),
`tokyonight` como colorscheme, `snacks_animate = false`.

- **Harpoon 2**: `<leader>a` adiciona, `<leader>A` limpa, `<C-e>` menu,
  `<S-p>`/`<S-n>` navega.
- **Telescope** fixado em 0.1.8 (`<C-p>` files, `<leader>fG/fB`).
- **toggleterm**: pilha de exatamente 3 terminais (`<A-1..3>`, `<C-\>`);
  altura cresce por terminal aberto, e o 4º é negado com aviso.
- **LSP** (`config/lsp.lua` + `mason.lua`): ts_ls, html, cssls, clangd,
  cmake e intelephense (PHP com K&R e root por composer.json/.git),
  instalados via Mason (`ensure_installed` com jdtls).
- **DAP** (`config/dap.lua`): codelldb (Mason) para C/C++ com prompt de
  executável; keymaps `<leader>d*` globais.
- **Java** (`plugins/java.lua` + `java_menu/`): o coração customizado.
  - `nvim-jdtls` é o **dono único** do cliente jdtls por projeto
    (root por pom/gradle/agregador Maven); o autostart do lspconfig para
    jdtls é neutralizado (`filetypes = {}`) para não abrir um segundo
    cliente sem root_dir.
  - DAP Java com bundles OSGi do java-debug/java-test (Mason), filtrando os
    jars que não são bundles.
  - `jc.nvim` com mapas padrão desligados (`<leader>j*` vem do menu próprio).
  - **`java_menu/`** — plugin próprio (~15 módulos, com testes em
    `tests/java_menu/`): `:JavaNew` wizard de tipos/packages (class,
    interface, enum, record, annotation, test JUnit 5 em `src/test/java`),
    geração, refactors com segurança de WorkspaceEdit, imports, build/run
    Maven/Gradle (wrapper executável obrigatório para Gradle), testes via
    neotest com o adapter do jc, debug, preview e assinatura.
- `lazy-lock.json` versionado para travar as versões dos plugins.

## Wrappers de aplicativos e unidades systemd

Todos em `home/.local/bin/`, motivação unificada em
[troubleshooting.md](troubleshooting.md):

| Wrapper | O que faz |
| --- | --- |
| `set-xwayland-layout` | coloca todo display XWayland em `us-intl` (retry 5×) |
| `firefox-xwayland` | `MOZ_ENABLE_WAYLAND=0` + `GTK_IM_MODULE=simple`; o `firefox.desktop` versionado aponta para ele |
| `chromium` | garante `us-intl` no XWayland antes de abrir; o backend X11 vem de `chromium-flags.conf` |
| `zapfast-x11` | remove `WAYLAND_DISPLAY` (força X11) + `us-intl`; desktop entries e autostart apontam para ele |
| `omawrite-x11` | `QT_QPA_PLATFORM=xcb` (Qt; Wayland nativo não compõe dead keys) |
| `nectarlink-x11` | idem, Qt6 |

- `environment.d/20-gtk-im.conf` — `GTK_IM_MODULE=simple` para GTK 4.20+
  no Wayland (Hyprland não implementa text-input-v3).
- `environment.d/30-electron-x11.conf` — fallback para o hint x11 do
  Electron (o override efetivo está no `looknfeel.lua`).
- `environment.d/omarchy-firefox-wayland.conf` — mantém
  `MOZ_ENABLE_WAYLAND=0` globalmente.
- `environment.d/waystone.conf` — conta do PoE2 usada pelo overlay.
- `systemd/user/xwayland-us-intl.service` — oneshot no
  `graphical-session.target` que roda o `set-xwayland-layout` no login.
- `systemd/user/gsr-replay.service` — replay buffer do GPU Screen Recorder:
  60 s em RAM, MP4 60 fps CBR, clipes em `/data/midia/clipes`, gravações em
  `/data/midia/gravacoes`, IPC em `%t/gsr.sock`; espera o mount de `/data`
  por até 60 s antes de iniciar. **Atenção:** captura `-w HDMI-A-1` — é
  configuração desta máquina; o lugar natural desse unit seria o overlay do
  host.

## Skills e defaults do Omarchy

- `.agents/skills/omarchy/` — cópia versionada do skill de customização do
  Omarchy (guias de hyprland, plugins, theming, hooks, dotfiles), linkado
  como diretório inteiro para uso por agentes locais.
- `omarchy/defaults/` — `agent = opencode`, ditado = superwhisper.
- `omarchy/branding/` — logotipos ASCII do Omarchy (upstream).
- `omarchy/hooks/*.sample` — exemplos upstream, inativos por definirem.

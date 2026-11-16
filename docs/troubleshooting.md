# Troubleshooting: acentos e dead keys (todos os apps)

Este documento preserva o raciocínio técnico da estratégia de input deste
setup: por que os acentos quebram, o que foi tentado, e qual solução vale
para cada família de aplicativos.

## O problema

O problema nunca foi só do Firefox. Qualquer app que dependa do **text-input
do Wayland** com o layout `us-intl` erra a composição dos dead keys enquanto
o Hyprland não implementa `text-input-v3`. O resultado prático: `'` + `a`
não vira `á` (ou vira o caractere cru) em campos de texto desses apps.

Cada toolkit falha de um jeito diferente:

| Família | Backend em questão | Sintoma |
| --- | --- | --- |
| GTK 4.20+ | Wayland nativo, sem IM | sem compose: dead keys mortas (Ghostty, Nautilus, GTK em geral) |
| Firefox | Wayland nativo | acentos saem errados em campos web (Bugzilla 2004150) |
| Electron (Obsidian, Discord, …) | Wayland nativo | mesma falha de composição |
| Qt puro (Omawrite, NectarLink) | Wayland nativo | idem |
| winit/egui (ZapFast) | Wayland nativo | idem |
| X11/XWayland | keymap herdado do Hyprland | compõe certo, **mas não herda o variant `intl`** |

## A estratégia do repositório

1. **GTK compõe sozinho com `GTK_IM_MODULE=simple`**
   (`environment.d/20-gtk-im.conf`). O módulo `simple` devolve o compose
   nativo do GTK, que não precisa de IM do compositor. Se um dia for preciso
   IME de verdade (japonês, chinês, coreano), trocar por `fcitx` — os
   pacotes fcitx5 já estão no snapshot de pacotes.

2. **Todo XWayland em `us-intl`**: `~/.local/bin/set-xwayland-layout` roda
   `setxkbmap -layout us -variant intl` em cada display de
   `/tmp/.X11-unix/X*` (retry 5×, para cobrir displays que sobem depois). O
   unit `systemd/user/xwayland-us-intl.service` executa isso no login
   (`graphical-session.target`), e cada wrapper de app o re-executa por
   garantia antes de abrir o programa.

3. **Cada família de app vai para o backend que compõe certo:**

   - **Firefox** — `~/.local/bin/firefox-xwayland` força
     `MOZ_ENABLE_WAYLAND=0` + `GTK_IM_MODULE=simple`; o
     `.desktop` versionado (`~/.local/share/applications/firefox.desktop`)
     aponta para o wrapper, e
     `environment.d/omarchy-firefox-wayland.conf` mantém
     `MOZ_ENABLE_WAYLAND=0` para qualquer outro caminho de execução.
     *Remova o wrapper e volte para `MOZ_ENABLE_WAYLAND=1` quando o Firefox
     corrigir o backend Wayland.*

   - **Electron** — o override efetivo é `ELECTRON_OZONE_PLATFORM_HINT=x11`
     no `looknfeel.lua` (vence o `wayland` que o Omarchy define em
     `default/hypr/envs.lua`); `environment.d/30-electron-x11.conf` fica
     como fallback. Vale a partir do próximo login.

   - **Chromium** — `chromium-flags.conf` usa `--ozone-platform=x11`; o
     wrapper `~/.local/bin/chromium` garante o `us-intl` do XWayland antes
     de abrir (e mantém `--password-store=gnome-libsecret`).

   - **ZapFast (winit/egui)** — `~/.local/bin/zapfast-x11` remove
     `WAYLAND_DISPLAY` do ambiente (força X11) e garante o `us-intl`. O
     desktop entry (`zapfast.desktop`) e o autostart apontam para o wrapper,
     então abrir pelo ícone normal já passa por ele.

   - **Qt puro (Omawrite, NectarLink)** — o `QT_QPA_PLATFORM` global **não**
     pode ir para `xcb`, porque o Quickshell/bar também é Qt e ficaria no
     X11. Por isso cada app tem seu wrapper (`omawrite-x11`,
     `nectarlink-x11`) que exporta `QT_QPA_PLATFORM=xcb` só para ele; o dock
     e o autostart já apontam para os wrappers.

## Por que os `environment.d` não bastavam

O Omarchy define `MOZ_ENABLE_WAYLAND=1` e
`ELECTRON_OZONE_PLATFORM_HINT=wayland` em `default/hypr/envs.lua`, e essas
definições **vencem** o `environment.d` (ordem de carregamento do ambiente
da sessão Hyprland). O override efetivo migrou para o `looknfeel.lua`, que
carrega depois dos defaults — daí o `hl.env(...)` lá em vez de só conf nos
`.conf`.

## Como aplicar / reverter

- **Firefox, ZapFast, Chromium**: reinicie o aplicativo (o wrapper é lido a
  cada execução).
- **Electron**: faça logout/login uma vez (o hint é variável de ambiente da
  sessão).
- **Quando um app corrigir o Wayland**: remova o wrapper correspondente,
  aponte o desktop entry de volta ao binário original e reverta a variável
  (`MOZ_ENABLE_WAYLAND=1`, hint `wayland`, ou remova `QT_QPA_PLATFORM=xcb`).
  Cada passo de reversão está comentado no próprio arquivo versionado.

## Limitações conhecidas

- Os wrappers forçam X11/XWayland: recursos exclusivos de Wayland nativo
  (fração de scaling por monitor, screencopy seletivo) não valem para esses
  apps enquanto o workaround estiver ativo.
- `set-xwayland-layout` só cobre displays que já existem no momento da
  execução; displays X11 criados depois dependem do wrapper do app (que
  sempre re-executa antes de abrir).
- O `GDK_SCALE` (GTK/X11) só aceita inteiros — o scale fracionário fica por
  conta do Hyprland para janelas Wayland nativas (ver `monitors.lua`).
- Se o Hyprland um dia implementar `text-input-v3` com compose completo, a
  recomendação é desligar a estratégia por camadas: wrappers, hints do
  `looknfeel.lua` e o unit `xwayland-us-intl.service` podem ser removidos
  nessa ordem, testando app por app.

## Outros problemas comuns

- **Bar não sobe depois de atualizar plugins**: `omarchy restart shell`.
- **Terminais sem tema após trocar de tema**: feche e reabra o Ghostty; os
  temas são lidos do `~/.local/state/omarchy/current/theme/` na inicialização.
- **gsr-replay falha no boot**: o unit espera `/data` montar por até 60 s;
  sem o mount (ou sem `/data/midia/clipes`), o serviço desiste. Veja
  `systemctl --user status gsr-replay`.

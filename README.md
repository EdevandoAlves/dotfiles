# dotfiles

Configuração deste Omarchy em `~/dotfiles`, com a árvore de `home/` espelhando o
`$HOME`. Cada arquivo vira um symlink no lugar original; plugins e temas são
linkados como diretório inteiro.

## Instalação em uma máquina nova

Pré-requisitos: Omarchy já instalado, `python3` e `git`.

```bash
git clone <url-do-repo> ~/dotfiles
cd ~/dotfiles
./scripts/install.sh
```

O `install.sh`:

1. instala os pacotes de `packages/pacman.txt` e `packages/aur.txt`;
2. cria os symlinks com `scripts/link.py`;
3. tenta aplicar o tema **Aether** e o wallpaper padrão;
4. recarrega systemd, shell e terminal.

Se os pacotes já estiverem instalados, use só os links:

```bash
python3 scripts/link.py
```

Para ver o que seria feito, sem tocar em nada:

```bash
python3 scripts/link.py --dry-run
```

## O que fica centralizado

- `~/.agents/skills/omarchy/` — skill local com o guia de dotfiles
- `~/.config/hypr/*.lua` e `.conf`
- `~/.config/omarchy/shell.json`, `shell.toml`, `language`, `keyboard-layouts`
- `~/.config/omarchy/extensions/`, `hooks/`, `themed/`, `branding/`, `defaults/`
- `~/.config/omarchy/themes/fedora-42/` e `aether/`
- `~/.config/omarchy/plugins/omacale.bar/` (cópia modificada do plugin)
- `~/.config/omarchy/plugins/vz.lock`, `vz.notifications`, `vz.osd`
- `~/.config/omacale/settings.json`
- `~/.config/ghostty/config` + `local.conf`
- `~/.config/foot`, `alacritty`, `kitty`
- `~/.config/fish/`, `nvim/`, `btop/`, `starship.toml`, `git/config`
- `~/.config/environment.d/`, `fontconfig/`, `gtk-3.0/`, `gtk-4.0/`
- `~/.config/mimeapps.list`, `hyprland-mimeapps.list`
- `~/.config/systemd/user/gsr-replay.service`

O que é da máquina fica em `hosts/<hostname>/` e é sobreposto por cima do
`home/`. Hoje: `hosts/visao/` com `monitors.lua` e `autostart.lua`.

## O que **não** entra

- Chaves SSH/GPG, tokens (`gh`, Bitwarden, Hermes, etc.)
- Perfis de navegador, Steam, Heroic, `~/.local/share`
- `~/.local/state`, caches, `plugins-backups`, `*.bak.*`
- `~/.face` (opcional e pessoal)

## Segurança e reversão

Antes de substituir qualquer arquivo existente, o `link.py` move o original
para:

```
~/.dotfiles-backup/<data-hora>/
```

Para reverter um arquivo, remova o symlink e copie de volta o original desse
backup. O diretório de backup não é versionado.

## Detalhes importantes

- **Omacale**: o `omacale.bar` aqui é uma cópia editada (relógio, tray, lock,
  traduções etc.). Atualizações do Omacale precisam ser mescladas neste fork.
- **vz.***: são clones gerados pelo handover do Omacale. Estão versionados para
  reproduzir o lock/notificações/OSD exatos; se o Omacale reinstalar, rode
  `python3 scripts/link.py` de novo.
- **Aether**: o tema é gerado a partir do wallpaper. A pasta atual está
  versionada; se o Aether regenerar, as mudanças aparecem no repo.
- **Superwhisper**: o `superwhisper-panel` é um symlink para `/opt`. Instale o
  Superwhisper na máquina nova; o dotfiles não copia o `/opt`.
- **Pacotes**: `packages/pacman.txt` é o `pacman -Qqe` desta máquina. Revise
  itens específicos de hardware (`amd-ucode`, etc.) antes de instalar em outro
  PC.

## Acentos e dead keys (todos os apps)

O problema não é só do Firefox: apps que usam o text-input do Wayland e o
layout `us-intl` (Firefox, Chromium/Electron, ZapFast/winit) erram a composição
dos dead keys. GTK funciona via `GTK_IM_MODULE=simple`. A estratégia do repo é:

- **XWayland em `us-intl` para todos:** `set-xwayland-layout` +
  `xwayland-us-intl.service` (systemd user) colocam todo display XWayland em
  `us-intl` no login.
- **Firefox:** `home/.local/bin/firefox-xwayland` força
  `MOZ_ENABLE_WAYLAND=0` + `GTK_IM_MODULE=simple`;
  `home/.local/share/applications/firefox.desktop` aponta para ele;
  `environment.d/omarchy-firefox-wayland.conf` mantém `MOZ_ENABLE_WAYLAND=0`.
- **ZapFast (winit/egui):** `home/.local/bin/zapfast-x11` remove
  `WAYLAND_DISPLAY` (força X11); o desktop entry e o autostart apontam para ele.
- **Chromium:** `chromium-flags.conf` usa `--ozone-platform=x11`; o wrapper
  `home/.local/bin/chromium` garante o `us-intl` antes de abrir.
- **Electron (Obsidian, Discord, etc.):** `looknfeel.lua` sobrepõe o default
  do Omarchy com `ELECTRON_OZONE_PLATFORM_HINT=x11`; vale a partir do próximo
  login. O `environment.d/30-electron-x11.conf` fica como fallback.
- **Qt puro (Omawrite, NectarLink):** o `QT_QPA_PLATFORM` global não pode ir
  para `xcb` porque o Quickshell/bar também é Qt. Então esses dois usam
  wrappers (`omawrite-x11`, `nectarlink-x11`), e o dock/autostart já apontam
  para eles; você continua abrindo pelo ícone normal.
- **Por que os `environment.d` não bastavam:** o Omarchy define
  `MOZ_ENABLE_WAYLAND=1` e `ELECTRON_OZONE_PLATFORM_HINT=wayland` no
  `default/hypr/envs.lua`, que vence o `environment.d`. O override agora está
  no `looknfeel.lua`, que carrega depois.

Para aplicar: reinicie Firefox, ZapFast e Chromium; para o Electron, faça
logout/login uma vez. Quando os apps corrigirem o Wayland, remova o wrapper
correspondente e volte ao backend nativo.

## Atualizar

```bash
cd ~/dotfiles
git pull
python3 scripts/link.py   # se novos arquivos entraram no repo
```

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

## Firefox e acentos (dead keys)

O Firefox em Wayland nativo tem um bug conhecido com `us-intl` + Hyprland
(Bugzilla 2004150): os dead keys saem errados. O repo contorna isso com:

- `home/.local/bin/firefox-xwayland` — força `MOZ_ENABLE_WAYLAND=0`,
  `GTK_IM_MODULE=simple` e aplica `us-intl` no XWayland antes de abrir;
- `home/.local/share/applications/firefox.desktop` — aponta o launcher para
  esse wrapper;
- `home/.config/environment.d/omarchy-firefox-wayland.conf` — mantém
  `MOZ_ENABLE_WAYLAND=0` para os próximos logins.

Feche **todas** as janelas do Firefox e abra de novo pelo launcher. Quando o
Firefox corrigir o backend Wayland, remova o wrapper e volte
`MOZ_ENABLE_WAYLAND=1`.

## Atualizar

```bash
cd ~/dotfiles
git pull
python3 scripts/link.py   # se novos arquivos entraram no repo
```

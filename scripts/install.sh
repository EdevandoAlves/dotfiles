#!/usr/bin/env bash
# Instala as configs deste repo em uma máquina Omarchy.
# Uso:
#   ./scripts/install.sh                # pacotes + links + tema
#   ./scripts/install.sh --no-packages  # só links + tema
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v omarchy >/dev/null 2>&1; then
  echo "Omarchy não encontrado. Instale o Omarchy primeiro." >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 é necessário." >&2
  exit 1
fi

if [[ "${1:-}" != "--no-packages" ]]; then
  echo "== Pacotes do repositório =="
  if command -v pacman >/dev/null 2>&1; then
    # omarchy já veio com a instalação base; os demais são --needed.
    mapfile -t PKGS < <(grep -vx 'omarchy' "$ROOT/packages/pacman.txt" | grep -v '^$')
    sudo pacman -S --needed --noconfirm "${PKGS[@]}" || \
      echo "Aviso: algum pacote do repositório falhou; veja a saída acima."
  fi

  echo "== Pacotes AUR =="
  if command -v yay >/dev/null 2>&1; then
    yay -S --needed --noconfirm $(grep -v '^$' "$ROOT/packages/aur.txt") || \
      echo "Aviso: algum pacote AUR falhou; veja a saída acima."
  elif command -v paru >/dev/null 2>&1; then
    paru -S --needed --noconfirm $(grep -v '^$' "$ROOT/packages/aur.txt") || \
      echo "Aviso: algum pacote AUR falhou; veja a saída acima."
  else
    echo "yay/paru não encontrado. Instale os AURs manualmente:"
    cat "$ROOT/packages/aur.txt"
  fi
fi

echo "== Links =="
python3 "$ROOT/scripts/link.py"

echo "== Tema e wallpaper =="
if omarchy theme list 2>/dev/null | grep -qi 'aether'; then
  omarchy theme set aether || echo "Aviso: não consegui aplicar o tema Aether."
  BG="$HOME/.config/omarchy/themes/aether/backgrounds/1-f42-day.jpg"
  if [[ -f "$BG" ]]; then
    omarchy theme bg set "$BG" || true
  fi
fi

systemctl --user daemon-reload 2>/dev/null || true
systemctl --user enable --now xwayland-us-intl.service 2>/dev/null || \
  echo "Aviso: xwayland-us-intl.service não pôde ser ativado agora."

if [[ -d /opt/superwhisper ]]; then
  echo "Superwhisper encontrado."
else
  echo "Superwhisper não está em /opt; instale-o se quiser o painel dele no bar."
fi

echo "== Shell =="
omarchy restart shell >/dev/null 2>&1 || true

cat <<'EOF'

Pronto.

Feche e abra o terminal (ou abra uma nova aba) para pegar Ghostty/fish.
Se o bar não aparecer, rode: omarchy restart shell
Se algum arquivo antigo tiver sido substituído, o original está em:
  ~/.dotfiles-backup/<data-hora>/
EOF

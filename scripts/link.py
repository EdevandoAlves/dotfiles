#!/usr/bin/env python3
"""Liga ~/dotfiles/home (e o overlay do host) em ~ por symlink.

- Cada arquivo do repo vira um symlink no caminho original.
- Diretórios que precisam ser centralizados por inteiro (plugins e temas)
  entram como um symlink só.
- O que já existe e não é o link certo é movido para
  ~/.dotfiles-backup/<data-hora>/ antes de ser substituído.
- Rodar de novo é seguro: links já corretos são ignorados.
"""
from __future__ import annotations

import os
import shutil
import socket
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HOME = Path.home()
HOST = os.environ.get("DOTFILES_HOST") or socket.gethostname()
DRY = "--dry-run" in sys.argv

# Diretórios centralizados inteiros (plugins e temas). Tudo o que estiver
# dentro deles é linkado pelo diretório, não arquivo a arquivo.
WHOLE = [
    ".config/omarchy/plugins/omacale.bar",
    ".config/omarchy/plugins/vz.lock",
    ".config/omarchy/plugins/vz.notifications",
    ".config/omarchy/plugins/vz.osd",
    ".config/omarchy/themes/fedora-42",
    ".config/omarchy/themes/aether",
]

BACKUP = HOME / ".dotfiles-backup" / time.strftime("%Y%m%d-%H%M%S")


def under_whole(rel: str) -> bool:
    return any(rel == w or rel.startswith(w + "/") for w in WHOLE)


def backup(dst: Path, rel: str) -> None:
    if not (dst.exists() or dst.is_symlink()):
        return
    target = BACKUP / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    if DRY:
        print(f"  backup {dst} -> {target}")
        return
    if target.exists() or target.is_symlink():
        target = target.with_name(target.name + f".{int(time.time())}")
    shutil.move(str(dst), str(target))
    print(f"  backup {dst} -> {target}")


def link(src: Path, dst: Path, rel: str) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.is_symlink():
        try:
            if dst.resolve() == src.resolve():
                print(f"  ok     {dst}")
                return
        except OSError:
            pass
    backup(dst, rel)
    if DRY:
        print(f"  link   {dst} -> {src}")
        return
    dst.symlink_to(os.path.relpath(src, dst.parent))
    print(f"  link   {dst} -> {os.path.relpath(src, dst.parent)}")


def link_tree(source: Path, label: str) -> None:
    """Linka os arquivos de uma árvore, pulando os WHOLE."""
    if not source.exists():
        return
    for path in sorted(source.rglob("*")):
        if not path.is_file() or path.name == ".gitkeep":
            continue
        rel = str(path.relative_to(source))
        if under_whole(rel):
            continue
        print(f"[{label}] {rel}")
        link(path, HOME / rel, rel)


def main() -> int:
    print(f"dotfiles: {ROOT}")
    print(f"host:     {HOST}")
    if DRY:
        print("modo:     dry-run\n")
    else:
        print(f"backup:   {BACKUP}\n")

    # 1. Plugins e temas: um symlink para o diretório inteiro.
    for rel in WHOLE:
        src = ROOT / "home" / rel
        if not src.exists():
            print(f"[skip] {rel} (não existe no repo)")
            continue
        print(f"[whole] {rel}")
        link(src, HOME / rel, rel)

    # 2. O resto do home, arquivo a arquivo.
    link_tree(ROOT / "home", "home")

    # 3. Overlay do host atual (monitores, autostart, etc.).
    host_root = ROOT / "hosts" / HOST
    if host_root.exists():
        link_tree(host_root, f"host:{HOST}")
    else:
        print(f"[host] hosts/{HOST} não existe; nada a sobrepor")

    print("\npronto.")
    if not DRY:
        print(f"backup dos originais em: {BACKUP}")
        print("reinicie o shell/terminal para pegar tudo:")
        print("  omarchy restart shell && omarchy restart terminal")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

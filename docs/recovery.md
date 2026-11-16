# Recovery: backup, reversão e riscos

Como o `link.py` protege o que já existe na máquina, e como voltar atrás
quando algo der errado.

## Estratégia de backup

Antes de substituir **qualquer** arquivo existente, o `link.py` move o
original para:

```text
~/.dotfiles-backup/<data-hora>/<caminho-relativo-original>/
```

- Um diretório novo por execução (`20251116-153000/`, por exemplo). Rodar de
  novo nunca sobrescreve um backup anterior.
- Colisão de nome dentro do mesmo run é resolvida com sufixo de época
  (`arquivo.1731774600`).
- O diretório de backup **não é versionado** (`.gitignore`) e não é tocado
  pelo repositório — é a única cópia do estado pré-dotfiles da máquina.
- Symlinks pré-existentes também são movidos (o link em si, não o alvo) —
  por exemplo, links criados por outras ferramentas de dotfiles.
- Rodar o `link.py` de novo é seguro: symlinks que já apontam para o lugar
  certo são detectados via `resolve()` e pulados, sem backup novo.

## Comportamento dos symlinks

- Cada arquivo do repo vira um symlink **relativo** no caminho original
  (`symlink_to(relpath)`), então mover/clonar o `~/dotfiles` não quebra os
  links.
- Diretórios inteiros (`omacale.bar`, `vz.*`, temas, skill do Omarchy)
  recebem um único symlink de diretório — o conteúdo interno nunca é
  espalhado arquivo a arquivo.
- O overlay do host (`hosts/<hostname>/`) substitui o mesmo caminho do
  `home/`; a versão comum não chega a ser linkada.
- Diretórios-pai são criados com `mkdir -p` conforme necessário.

## Como reverter um arquivo

```bash
# 1. Descubra o backup mais recente que contém o arquivo
ls -dt ~/.dotfiles-backup/*/ | head -1
#    → procure o caminho relativo dentro dele, ex.:
#    ~/.dotfiles-backup/20251116-153000/.config/ghostty/config

# 2. Remova o symlink e copie o original de volta
rm ~/.config/ghostty/config
cp ~/.dotfiles-backup/20251116-153000/.config/ghostty/config ~/.config/ghostty/config
```

Para **reverter tudo** de um run (raro, mas possível):

```bash
BK=~/.dotfiles-backup/<data-hora>
(cd "$BK" && find . -mindepth 1 | while read -r f; do
   dest="$HOME/${f#./}"
   if [ -L "$dest" ]; then rm -- "$dest"; fi
   mkdir -p -- "$(dirname -- "$dest")"
   [ -f "$BK/$f" ] && cp -a -- "$BK/$f" "$dest"
 done)
```

Depois de reverter, `omarchy restart shell` devolve o desktop ao estado
anterior.

## O que NÃO está coberto

- **Estado gerado depois do link**: perfis de navegador, databases de apps,
  `~/.local/state`, caches — nunca versionados, nunca backupados. Reverter
  o link não desfaz mudanças que os apps fizeram nesses lugares.
- **`/opt/superwhisper`**: o painel do bar é um symlink para lá; o dotfiles
  não copia nem restaura o `/opt`.
- **Secrets**: chaves SSH/GPG, tokens (`gh`, Bitwarden, Hermes) estão fora
  do repo por design (`.gitignore`) — se perdeu, não há backup aqui.
- **Pacotes**: o rollback de config não desinstala o que o `install.sh`
  instalou. Não há "uninstall" de pacotes; remova à mão se preciso.
- **Temas regenerados**: se o Aether regenerar a paleta, o conteúdo novo
  aparece como diff no repo (a pasta é versionada); o backup do `link.py`
  não participa desse fluxo.

## Riscos conhecidos

1. **Backups se acumulam sem poda.** Cada run cria um diretório novo com
   cópia integral do que foi substituído. Não é grande (configs são
   pequenas), mas vale revisar `du -sh ~/.dotfiles-backup` de vez em quando
   e apagar runs antigos **depois** de confirmar que a máquina está estável.
2. **`install.sh` engole falhas de pacote** (`|| echo aviso`): um run
   "bem-sucedido" pode ter deixado pacotes para trás. Confira a saída; o
   exit code 0 não garante nada sobre o passo de pacotes.
3. **Primeiro run substitui a config viva do Omarchy** — é o objetivo, mas
   significa que o desktop pode mudar (bar, bindings, temas) no mesmo
   instante em que os links são criados. Prefira `--dry-run` antes, e
   `link.py` sem pacotes primeiro, para poder voltar com o passo acima.
4. **Múltiplas máquinas**: um `hosts/<hostname>/` ausente não é erro — o
   `link.py` apenas usa o `home/` comum e avisa. Em hardware diferente,
   `monitors.lua`/`gsr-replay.service` desta máquina podem não fazer sentido
   (HDMI-A-1, `/data`); crie o overlay da máquina antes de linkar.
5. **O backup guarda o estado no momento do link.** Se um app alterar o
   arquivo original *depois* (ex.: ferramenta que reescreve config), essa
   mudança só existirá no backup do run seguinte. Não há versionamento
   contínuo do lado de fora do git.

## Checklist pós-instalação

```bash
readlink -e ~/.config/hypr/hyprland.lua     # aponta para ~/dotfiles/home/...?
omarchy theme list | grep -i aether          # tema presente?
systemctl --user is-enabled xwayland-us-intl.service
omarchy restart shell                        # bar volta?
```

Se algo estiver errado, o caminho de volta é sempre: remover o symlink e
copiar do `~/.dotfiles-backup/<data-hora>/` correspondente.

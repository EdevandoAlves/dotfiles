# Instalação

Este documento descreve como reproduzir este ambiente em uma máquina com
Omarchy já instalado. O repositório **não** instala o Omarchy nem substitui
uma distribuição: ele sobrepõe configuração por cima da instalação padrão.

## Pré-requisitos

- **Omarchy instalado** — o `install.sh` verifica `omarchy` no `PATH` e
  aborta se não encontrar. Testado com Omarchy 4.x / Hyprland com config em
  Lua (0.5x).
- `git` e `python3` (o `link.py` usa apenas a biblioteca padrão).
- Um AUR helper **apenas** para o instalador completo: `yay` (preferencial)
  ou `paru`. Sem ele, o script lista os pacotes AUR para instalação manual.
- `sudo` funcionando para o `pacman` do modo completo.

```bash
git clone https://github.com/EdevandoAlves/dotfiles ~/dotfiles
cd ~/dotfiles
```

## Modos de instalação

### 1. Pré-visualização (não modifica nada — quase)

```bash
python3 scripts/link.py --dry-run
```

Lista arquivo por arquivo o que seria linkado e o que seria movido para o
backup, sem criar nenhum symlink nem mover nada. **Observação:** o modo
dry-run ainda cria diretórios-pai que não existem (ex.: `~/.config/foo/`)
porque o `mkdir` roda antes do check de dry-run — em uma máquina Omarchy
esses diretórios já existem, então na prática não há efeito. Veja
[Limitações conhecidas](#limitações-conhecidas-do-linkpy).

### 2. Só os links (recomendado para testar a config)

```bash
python3 scripts/link.py
```

Cria os symlinks de todo o `home/` (e do overlay do host) sem instalar
pacote nenhum. É o modo seguro: se a config não agradar, é só restaurar do
backup (ver [recovery.md](recovery.md)). Plugins e temas
(`omacale.bar`, `vz.*`, temas, skill do Omarchy) entram como um symlink por
diretório inteiro, não arquivo a arquivo.

Antes de rodar, confira o que seria feito com `--dry-run`. Depois de rodar,
confira o resultado:

```bash
ls -la ~/.config/hypr/           # links devem apontar para ~/dotfiles/home/...
readlink ~/.config/ghostty/config
systemctl --user list-unit-files | grep xwayland
```

### 3. Instalador completo (pacotes + links + tema)

```bash
./scripts/install.sh                # pacotes + links + tema + serviços
./scripts/install.sh --no-packages  # links + tema, sem pacman/yay
```

O que o `install.sh` faz, em ordem:

1. **Pacotes pacman** — instala tudo de `packages/pacman.txt` com
   `pacman -S --needed --noconfirm` (o pacote `omarchy` em si é filtrado da
   lista, pois já veio com a base). Qualquer falha é apenas *avisada* — o
   script segue em frente.
2. **Pacotes AUR** — `yay -S --needed --noconfirm` (ou `paru`) com
   `packages/aur.txt`. Sem AUR helper, só imprime a lista.
3. **Links** — roda `scripts/link.py` (movendo originais para o backup).
4. **Tema** — `omarchy theme set aether` e aplica o wallpaper
   `themes/aether/backgrounds/1-f42-day.jpg` se existir.
5. **Serviços** — `systemctl --user daemon-reload` e ativa
   `xwayland-us-intl.service`.
6. **Shell** — `omarchy restart shell`.

Ao final, feche e reabra o terminal (ou abra uma aba nova) para pegar
Ghostty/fish. Se o bar não subir: `omarchy restart shell`.

## Comportamento dos pacotes

`packages/pacman.txt` é **um snapshot completo desta máquina**
(`pacman -Qqe`), não uma lista curada de dependências. Isso tem consequências:

- **`--noconfirm` automatiza tudo**, incluindo builds de AUR, que executam
  PKGBUILDs sem revisão. É a decisão de conveniência do dono do repo para a
  própria máquina; em hardware diferente, revise antes.
- **Pacotes específicos de hardware** estão na lista: `nvidia-open-dkms`,
  `nvidia-utils`, `lib32-nvidia-utils`, `libva-nvidia-driver` (GPU desta
  máquina), além de `amd-ucode` **e** `intel-ucode` (confira qual microcode
  corresponde à sua CPU), `linux-firmware` e o kernel `linux-omarchy`. Em
  outra máquina, remova o que não se aplicar **antes** de rodar o
  instalador — `--needed` só pula pacotes já instalados; um driver de outra
  vendor que não existe na máquina **seria instalado** normalmente.
- **Serviços e integrações** dependem de coisas fora do repo: o
  `gsr-replay.service` grava para `/data/midia/clipes` (HD montado
  separadamente) e captura a saída `HDMI-A-1`; sem esse mount/output o
  serviço falha (ele espera o mount por até 60 s e desiste).
- **Superwhisper** não é coberto: o bar referencia o painel dele via symlink
  para `/opt/superwhisper`. Instale o Superwhisper à mão na máquina nova; o
  `install.sh` apenas avisa se não encontrar.
- **Hermes, Bitwarden CLI, exercism etc.** instalam, mas os *dados* deles
  (secrets, perfis) nunca entram no repo — ver
  [O que o repositório não versiona](#o-que-o-repositório-não-versiona).

O `--no-packages` existe exatamente para separar essas duas preocupações:
testar/replicar a *configuração* sem alterar o sistema de pacotes.

## Hosts e configuração por máquina

`scripts/link.py` descobre o hostname e aplica `hosts/<hostname>/` por cima
do `home/` — o mesmo caminho relativo no overlay vence, e o arquivo do
`home/` comum não é linkado duas vezes. Hoje existe um host:

- `hosts/visao/` — `monitors.lua` (HDMI-A-1 1080p@75 + scale auto) e
  `autostart.lua` (sobe o Waystone).

Para forçar um overlay em outra máquina (ou testar):

```bash
DOTFILES_HOST=visao python3 scripts/link.py --dry-run
```

Para adicionar uma máquina nova, crie `hosts/<hostname>/` espelhando só os
arquivos que divergem do `home/`.

## Atualizando

```bash
cd ~/dotfiles
git pull
python3 scripts/link.py   # aplica arquivos novos; links corretos são ignorados
```

Rodar de novo é idempotente: o `link.py` compara o alvo de cada symlink e
pula o que já está certo. Backup só é feito de arquivo que mudou.

## O que o repositório não versiona

Por design (ver `.gitignore`):

- Chaves SSH/GPG, tokens (`gh`, Bitwarden, Hermes), `~/.face`;
- Perfis de navegador, Steam, Heroic, `~/.local/share` gerado (o código
  próprio em `.local/bin` e `.local/share/pdf2epub` é a exceção versionada);
- `~/.local/state`, caches, `plugins-backups`, `*.bak.*`;
- `~/.dotfiles-backup/` (os backups dos originais).

## Limitações conhecidas do link.py

Levantadas em auditoria (nenhuma corrigida neste repositório — mudanças de
código são propostas à parte):

1. **Dry-run cria diretórios.** O `mkdir -p` do destino roda antes do check
   de `DRY` em `link()`. Em máquinas Omarchy não muda nada (tudo já existe),
   mas em `$HOME` vazio o dry-run não é 100% sem efeito.
2. **Backups se acumulam.** Cada run cria um diretório
   `~/.dotfiles-backup/<data-hora>/` novo; nada é podado. Ver
   [recovery.md](recovery.md).
3. **Falha de pacote não falha o install.** O `install.sh` engole erros do
   `pacman`/`yay` com `|| echo aviso`, então o exit code é 0 mesmo com
   pacotes faltando. Confira a saída do passo 1/2 se algo estranho acontecer
   depois.
4. **AUR sem helper.** Sem `yay`/`paru`, os pacotes AUR não são instalados —
   o script apenas imprime a lista.

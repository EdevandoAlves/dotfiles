# pdf2epub

Conversor local PDF → EPUB3 para livros técnicos: Marker (layout/OCR) → Markdown → Pandoc.

## Uso

```bash
pdf2epub "livro.pdf"                       # perfil auto
pdf2epub --quality fast "livro.pdf"        # CPU, ~10 s por 4 páginas
pdf2epub --quality best "livro.pdf"        # VLM na GPU, ~12 s por página
pdf2epub --output ~/livros --title "X" --author "Y" --lang pt-BR "livro.pdf"
```

Saída padrão: `~/Downloads/epub-output/<nome>.epub`. Nunca sobrescreve sem confirmação.
Livros longos são convertidos em blocos de páginas e unidos em um único EPUB — não
precisa fazer nada para isso acontecer.

## Perfis

| Perfil | Motor | Qualidade | Observação |
|---|---|---|---|
| `fast` | Indra ONNX (CPU) | texto bom, figuras viram tabelas | sempre disponível |
| `best` | Surya 2.5 VLM em vLLM/Docker (GPU) | figuras e hierarquia reais | exige GPU livre |
| `auto` | `best` se validado nesta máquina, senão `fast` | — | selo: `vlm-verified` |

## Memória e blocos

O Marker processa o PDF inteiro e mantém o cache de `pdftext` de todas as páginas.
Num livro grande isso estoura a RAM: sem blocos, um PDF de 589 páginas chega a
~14 GB de RSS, o swap satura e o `systemd-oomd` mata o *scope* inteiro — o que
fecha a janela do terminal (não é crash do pdf2epub).

Por isso a conversão é dividida:

| Opção | Padrão | Efeito |
|---|---|---|
| `--chunk-pages N` | 50 no `fast`, bloco único no `best` | páginas por execução do Marker |
| `--mem-max TAM` | `8G` | teto de RAM por bloco via cgroup do `systemd-run` |

Cada bloco roda em um cgroup próprio. Se estourar o teto, morre só aquele bloco
(o script refaz pela metade, até 4 níveis) e o desktop continua vivo. No
`best` o bloco único é de propósito: cada execução reinicia o servidor VLM (~5 min).

Ajustáveis por ambiente: `PDF2EPUB_CHUNK_PAGES`, `PDF2EPUB_MEM_MAX`.

Medido nesta máquina (19 GB RAM, RTX 2060 Super): 50 páginas ≈ 2 GB de pico por
bloco; 60 páginas ≈ 2,2 GB.

## Hardware calibrado

RTX 2060 Super (Turing, SM 7.5, 8 GB). vLLM não aceita `bfloat16` aqui, e ~4 GB
da VRAM ficam com os workers do Superwhisper. Por isso o perfil `best` usa:

```
VLLM_GPU_TYPE=t4 VLLM_DTYPE=float16 VLLM_GPU_MEMORY_UTILIZATION=0.45
```

Se o vLLM não subir, feche apps que usam a GPU ou use `--quality fast`.
O startup do servidor leva ~5 min por conversão e o container é removido no fim.

## Arquivos

- `venv/` — Marker 2.2.0 com torch CPU (Python 3.12, gerenciado por uv) — **não é versionado nos dotfiles**; recrie com `uv venv venv && uv pip install --python venv/bin/python "marker-pdf==2.2.0"`
- `marker-runner.py` — executa o CLI do Marker corrigindo bugs desta versão
  (páginas sem nenhum bloco quebravam o `SectionHeaderProcessor`)
- `technical.css` — estilos do EPUB (código, tabelas, figuras, modo escuro)
- `html-fix.lua` — normaliza HTML bruto do Marker para XHTML válido
- `figure-repair.py` — recupera figuras que o Marker deixou de extrair:
  casa as figuras embutidas do PDF com os recortes do Marker (template
  matching, tolerante a figuras fundidas), descarta por OCR painéis de texto
  já transcritos, e recorta do PDF em alta resolução o que faltou — inclusive
  no lugar das referências fantasmas `![]()`
- `vlm-verified` — selo que habilita `auto` → `best` (estado da máquina, não versionado)
- `pdf2epub` — executável em `~/.local/bin/pdf2epub` (já está no PATH)

## Garantia de figuras

Depois de unir os blocos, o `pdf2epub` compara as figuras embutidas do PDF com
as imagens que entraram no Markdown e recupera as ausentes do próprio PDF.
Para isso o Marker roda com paginação (`--config_json` com `paginate_output`),
o que dá a cada trecho do Markdown a página de origem. Opções relacionadas:

| Opção | Padrão | Efeito |
|---|---|---|
| `--work-dir DIR` | — | reaproveita um workspace preservado (pula o Marker) |
| `--highres-dpi N` | 192 | DPI do render para OCR/figuras; em scans de ~72 dpi use ~120 |
| `--lowres-dpi N` | 96 | DPI do render de layout |

## Validação

Cada conversão falha (sem gravar o EPUB) se: o Markdown vier vazio, o ZIP/OPF/nav
estiverem inválidos, ou `epubcheck` reprovar. `pacman -S epubcheck` é opcional,
mas recomendado — sem ele só a validação estrutural interna roda.

## Limitações conhecidas

- Páginas escaneadas em ~144 dpi: os recortes de figura têm essa resolução máxima.
- Diagramas vetoriais complexos às vezes viram tabelas mesmo no `best`.
- Tabelas desenhadas à mão podem entrar como texto (tabela Markdown) em vez de
  imagem — o conteúdo está lá, só muda a apresentação.
- Página em que o layout/OCR não reconhece nenhum bloco (ex.: abertura de capítulo
  só com uma figura) é mantida vazia, com aviso no log — antes ela derrubava a
  conversão inteira.
- Livro de 589 páginas em `best` ≈ 2 h; em `fast` ≈ 9 min (12 blocos de 50 páginas).

## Dependências do sistema

`pandoc`, `poppler` (`pdfinfo`/`pdftoppm`), `epubcheck` (validação EPUB 3),
`tesseract` + `tesseract-data-eng` (descarte de painéis já transcritos),
`docker` + `nvidia-container-toolkit` (perfil `best`). Lista completa em
`~/dotfiles/packages/pacman.txt`.

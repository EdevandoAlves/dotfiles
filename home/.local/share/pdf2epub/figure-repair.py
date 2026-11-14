#!/usr/bin/env python3
"""Recupera figuras do PDF que o Marker não extraiu para o Markdown.

O Marker ocasionalmente deixa uma figura de fora: às vezes emite uma
referência sem caminho (``![]()``, que o Pandoc transforma em ``src="../"`` e o
epubcheck reprova) e às vezes perde a figura sem deixar rastro. As imagens
embutidas no PDF, porém, continuam lá.

Este utilitário:

1. lista as figuras embutidas em cada página do PDF (ignorando a imagem de
   fundo da página e ruído minúsculo);
2. casa cada figura com os recortes que o Marker gerou para aquela página
   (comparação de miniaturas recortadas no conteúdo);
3. para as figuras sem par, usa OCR (tesseract) para descartar painéis de
   texto que o Marker já transcreveu — só entra como imagem o que sumiu de
   verdade;
4. extrai a figura do próprio PDF em 300 dpi e a insere no Markdown: no lugar
   da referência fantasma daquela página, se houver, senão no fim da seção
   daquela página.

Requer pypdfium2 + numpy + Pillow (o venv do Marker já tem os três).

Uso:
  figure-repair.py --pdf LIVRO.pdf --md merged.md --pages pages.json \
                   --crops-dir work --out-dir merged [--dpi 300]

Imprime na saída padrão o número de figuras recuperadas.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import sys
import tempfile

import numpy as np
import pypdfium2 as pdfium
import pypdfium2.raw as raw
from PIL import Image

MIN_FRAC = 0.0008   # menor que isso é ruído/ícone
MAX_FRAC = 0.55     # maior que isso é a página inteira (fundo)
MIN_SIDE = 18.0     # pontos
SIM_OK = 0.55       # similaridade mínima para considerar "já extraída"
SIM_MERGE = 0.65    # idem para uma união de figuras fundidas em um recorte
OCR_KEEP = 0.60     # fração de palavras do OCR já presentes no texto => painel


def ink_thumb(im: Image.Image, n: int = 40) -> np.ndarray | None:
    """Miniatura normalizada do conteúdo escuro, ignorando margens brancas."""
    im = im.convert("L")
    mask = np.asarray(im) < 200
    if mask.sum() < 30:
        return None
    ys, xs = np.nonzero(mask)
    im = im.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    im.thumbnail((n, n), Image.LANCZOS)
    canvas = Image.new("L", (n, n), 255)
    canvas.paste(im, ((n - im.width) // 2, (n - im.height) // 2))
    v = 255.0 - np.asarray(canvas, dtype=np.float32)
    v -= v.mean()
    s = v.std()
    return v / s if s > 1.0 else None


def similarity(a: np.ndarray, b: np.ndarray) -> float:
    return float((a * b).mean())


def union_thumb(page, boxes, dpi: int = 150) -> np.ndarray | None:
    """Miniatura da união de vários recortes (o Marker às vezes funde figuras)."""
    if len(boxes) == 1:
        return ink_thumb(render(page, boxes[0], dpi))
    scale = dpi / 72.0
    left = min(b[0] for b in boxes)
    bottom = min(b[1] for b in boxes)
    right = max(b[2] for b in boxes)
    top = max(b[3] for b in boxes)
    canvas = Image.new("RGB", (max(1, int((right - left) * scale)),
                                max(1, int((top - bottom) * scale))), "white")
    for box in boxes:
        im = render(page, box, dpi)
        canvas.paste(im, (int((box[0] - left) * scale),
                          int((top - box[3]) * scale)))
    return ink_thumb(canvas)


def match_boxes(page, boxes, pool, max_merge: int = 3):
    """Marca as figuras do PDF já presentes nos recortes do Marker.

    Casa primeiro recortes com uma figura isolada e depois com uniões de 2..N
    figuras, porque o Marker costuma fundir diagramas vizinhos em um recorte só.
    Devolve os índices das figuras sem par.
    """
    from itertools import combinations

    remaining = list(range(len(boxes)))
    thumbs = {i: ink_thumb(render(page, boxes[i], 150)) for i in remaining}
    unused = list(pool)

    for size in range(1, max_merge + 1):
        if not unused:
            break
        if size > len(remaining):
            break
        limit = SIM_OK if size == 1 else SIM_MERGE
        for combo in combinations(remaining, size):
            if not unused:
                break
            if any(i not in remaining for i in combo):
                continue
            if size == 1:
                th = thumbs[combo[0]]
            else:
                th = union_thumb(page, [boxes[i] for i in combo])
            if th is None:
                continue
            best, idx = 0.0, -1
            for j, crop_th in enumerate(unused):
                s = similarity(th, crop_th)
                if s > best:
                    best, idx = s, j
            if best >= limit and idx >= 0:
                unused.pop(idx)
                for i in combo:
                    remaining.remove(i)
    return remaining


def page_figures(page) -> list[tuple[float, float, float, float]]:
    """Bounding boxes das figuras embutidas, de cima para baixo (ordem de leitura)."""
    w_page, h_page = page.get_size()
    area = w_page * h_page
    boxes = []
    for obj in page.get_objects():
        if obj.type != raw.FPDF_PAGEOBJ_IMAGE:
            continue
        left, bottom, right, top = obj.get_bounds()
        left, right = sorted((left, right))
        bottom, top = sorted((bottom, top))
        left, bottom = max(left, 0.0), max(bottom, 0.0)
        right, top = min(right, w_page), min(top, h_page)
        w, h = right - left, top - bottom
        if w < MIN_SIDE or h < MIN_SIDE:
            continue
        if not (MIN_FRAC <= (w * h) / area <= MAX_FRAC):
            continue
        boxes.append((left, bottom, right, top))
    boxes.sort(key=lambda b: (-b[3], b[0]))
    return boxes


def render(page, box, dpi: int) -> Image.Image:
    w_page, h_page = page.get_size()
    left, bottom, right, top = box
    # pypdfium2 espera margens (esq, base, dir, topo), não a bbox.
    crop = (left, bottom, w_page - right, h_page - top)
    return page.render(scale=dpi / 72.0, crop=crop).to_pil()


def ocr_text(im: Image.Image, lang: str) -> str | None:
    try:
        with tempfile.NamedTemporaryFile(suffix=".png") as tmp:
            im.save(tmp.name)
            res = subprocess.run(
                ["tesseract", tmp.name, "-", "-l", lang, "--psm", "6"],
                capture_output=True, text=True, timeout=180,
            )
        return res.stdout if res.returncode == 0 else None
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None


def already_transcribed(im: Image.Image, page_text: str, lang: str) -> bool:
    """True se o texto do recorte já aparece no Markdown (painel transcrito)."""
    text = ocr_text(im, lang)
    if not text:
        return False
    words = {w.lower() for w in re.findall(r"[0-9A-Za-zÀ-ÿ]{5,}", text)}
    if len(words) < 8:
        return False
    haystack = page_text.lower()
    hits = sum(1 for w in words if w in haystack)
    return hits / len(words) >= OCR_KEEP


def marker_crops(crops_dir: pathlib.Path) -> dict[int, list[np.ndarray]]:
    """Miniaturas dos recortes do Marker, por page_id local do bloco."""
    out: dict[int, list[np.ndarray]] = {}
    for cand in crops_dir.glob("chunk-*/**/_page_*"):
        if not cand.is_file():
            continue
        m = re.match(r"_page_(\d+)_", cand.name)
        if not m:
            continue
        try:
            th = ink_thumb(Image.open(cand))
        except Exception:
            continue
        if th is not None:
            out.setdefault(int(m.group(1)), []).append(th)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--pdf", required=True)
    ap.add_argument("--md", required=True, help="merged.md")
    ap.add_argument("--pages", required=True, help="pages.json gerado na junção")
    ap.add_argument("--crops-dir", required=True, help="workspace com os chunk-*/ do Marker")
    ap.add_argument("--out-dir", required=True, help="onde salvar as figuras recuperadas")
    ap.add_argument("--dpi", type=int, default=300)
    ap.add_argument("--ocr-lang", default="por")
    ap.add_argument("--no-ocr", action="store_true", help="não descartar painéis de texto")
    args = ap.parse_args()

    md_path = pathlib.Path(args.md)
    lines = md_path.read_text(encoding="utf-8").split("\n")
    pages = json.loads(pathlib.Path(args.pages).read_text(encoding="utf-8"))
    out_dir = pathlib.Path(args.out_dir)
    doc = pdfium.PdfDocument(args.pdf)
    crops = marker_crops(pathlib.Path(args.crops_dir))

    book_text = "\n".join(lines).lower()
    transcribed = skipped_no_ghost = 0
    insertions: list[tuple[int, str, bool, int]] = []  # (linha, ref, slot-fantasma, ordem)
    recovered: list[tuple[int, str]] = []

    for entry in pages:
        pid, abs_pid = entry["page"], entry.get("abs", entry["page"])
        start, end = entry["start"], entry["end"]
        if abs_pid >= len(doc):
            continue
        page = doc[abs_pid]
        boxes = page_figures(page)
        if not boxes:
            continue
        page_text = "\n".join(lines[start:end])

        page_crops = crops.get(pid, [])
        remaining = match_boxes(page, boxes, page_crops)
        ghosts = sorted(entry.get("ghosts", []))

        if page_crops and not ghosts:
            # A página tem recortes: as figuras "sem par" costumam ser metades
            # que o Marker fundiu em um recorte só, ou painéis de texto já
            # transcritos. Sem prova de perda, não arrisca duplicar.
            if remaining:
                skipped_no_ghost += len(remaining)
            continue

        built = 0
        for i in remaining:
            box = boxes[i]
            preview = render(page, box, 150)
            # Só na recuperação "página sem nenhum recorte" o OCR decide: painel
            # de texto já transcrito não entra de novo como imagem.
            if not page_crops and not args.no_ocr and already_transcribed(
                    preview, book_text, args.ocr_lang):
                transcribed += 1
                continue
            n = built
            built += 1
            fig = render(page, box, args.dpi)
            name = f"fig-pdf-p{abs_pid + 1:04d}-{n}.png"
            fig.save(out_dir / name)
            if ghosts:
                insertions.append((ghosts.pop(0), f"![]({name})", True, len(insertions)))
            else:
                insertions.append((end, f"![]({name})", False, len(insertions)))
            recovered.append((abs_pid + 1, name))

    for at, ref, is_ghost, _seq in sorted(insertions, key=lambda x: (x[0], x[3]), reverse=True):
        if is_ghost and at < len(lines) and not lines[at].strip():
            lines[at] = ref
        elif is_ghost and at < len(lines):
            lines[at] = lines[at].rstrip() + " " + ref
        else:
            lines.insert(min(at, len(lines)), ref)

    if recovered:
        md_path.write_text("\n".join(lines), encoding="utf-8")
        # O mapa de páginas precisa acompanhar as linhas inseridas, senão a
        # auditoria (e qualquer etapa seguinte) lê a seção errada.
        import bisect
        shifted = sorted(i for i, _ref, ghost, _seq in insertions if not ghost)
        for entry in pages:
            entry["start"] += bisect.bisect_left(shifted, entry["start"])
            entry["end"] += bisect.bisect_right(shifted, entry["end"])
            entry["ghosts"] = []
        pathlib.Path(args.pages).write_text(json.dumps(pages), encoding="utf-8")
    for pg, name in recovered:
        print(f"  página {pg}: figura recuperada do PDF -> {name}", file=sys.stderr)
    if transcribed:
        print(f"  {transcribed} painéis de texto já transcritos (não duplicados)",
              file=sys.stderr)
    if skipped_no_ghost:
        print(f"  {skipped_no_ghost} figura(s) do PDF em páginas que o Marker já converteu "
              f"(mantidas como estão, para não duplicar)", file=sys.stderr)
    print(len(recovered))
    return 0


if __name__ == "__main__":
    sys.exit(main())

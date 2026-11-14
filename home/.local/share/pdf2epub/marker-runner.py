#!/usr/bin/env python3
"""Executa o CLI do Marker com correções para bugs conhecidos desta versão.

Bug 1 (marker-pdf 2.2.0): páginas em que o layout/OCR não devolve nenhum bloco
ficam com ``children = None``. O fast path (Indra ONNX) não aplica a mesma
normalização do LayoutBuilder, então o SectionHeaderProcessor e os renderers
quebram com ``TypeError: 'NoneType' object is not iterable`` em livros que têm
páginas quase vazias. Aqui normalizamos ``children`` para lista depois que o
DocumentBuilder termina, antes dos processors — a página simplesmente sai vazia.

Uso: python marker-runner.py <argumentos do marker_single>
"""
import sys


def _patch_empty_pages() -> None:
    try:
        from marker.builders.document import DocumentBuilder
    except Exception:  # marker ausente/renomeado: segue sem patch
        return

    original = DocumentBuilder.__call__

    def patched(self, *args, **kwargs):
        document = original(self, *args, **kwargs)
        for page in getattr(document, "pages", []):
            if page.children is None:
                page.children = []
                print(
                    f"marker-runner: aviso: página {page.page_id} sem blocos "
                    f"(layout/OCR vazio); seguindo com página vazia",
                    file=sys.stderr,
                )
        return document

    DocumentBuilder.__call__ = patched


def main() -> int:
    _patch_empty_pages()
    from marker.scripts.convert_single import convert_single_cli

    return convert_single_cli()


if __name__ == "__main__":
    sys.exit(main())

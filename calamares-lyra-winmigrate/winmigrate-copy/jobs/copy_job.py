"""Lógica pura do job de cópia (PROMPT-CALAMARES-MIGRACAO-WINDOWS.md §5).

Sem dependência de `libcalamares`, para permitir testes unitários
isolados (ver tests/copy_job.test.py). O glue code que fala com o
Calamares fica em winmigrate-copy/main.py.
"""

import html
import json
import os
import subprocess

# O perfil do Firefox (diretório com sufixo aleatório) só é criado na
# primeira execução do navegador — não existe ainda na fase de
# instalação. Enquanto isso não acontece (ver Lyra Tour, §5), o HTML
# convertido fica em uma pasta de staging fixa, fora do perfil.
STAGING_BOOKMARKS_RELATIVE = os.path.join(".local", "share", "lyra", "bookmarks-importados.html")

NETSCAPE_HEADER = """<!DOCTYPE NETSCAPE-Bookmark-file-1>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks</H1>
<DL><p>
"""

NETSCAPE_FOOTER = "</DL><p>\n"


def rsync_copy(source_dir, dest_dir, run=subprocess.run):
    os.makedirs(dest_dir, exist_ok=True)
    proc = run(
        ["rsync", "-a", "--", source_dir + os.sep, dest_dir + os.sep],
        capture_output=True, text=True, check=False,
    )
    return proc.returncode == 0, (proc.stderr.strip() or None)


def _render_bookmark_node(node, depth):
    indent = "    " * depth
    node_type = node.get("type")
    if node_type == "folder":
        lines = [f'{indent}<DT><H3>{html.escape(node.get("name", ""))}</H3>', f"{indent}<DL><p>"]
        for child in node.get("children", []):
            lines.append(_render_bookmark_node(child, depth + 1))
        lines.append(f"{indent}</DL><p>")
        return "\n".join(lines)
    if node_type == "url":
        name = html.escape(node.get("name", node.get("url", "")))
        url = html.escape(node.get("url", ""), quote=True)
        return f'{indent}<DT><A HREF="{url}">{name}</A>'
    return ""


def chrome_bookmarks_to_netscape_html(chrome_json):
    """Converte o JSON de favoritos do Chrome/Edge para HTML Netscape (§5)."""
    roots = chrome_json.get("roots", {})
    body_parts = []
    for root in roots.values():
        if isinstance(root, dict):
            body_parts.append(_render_bookmark_node(root, 1))
    return NETSCAPE_HEADER + "\n".join(part for part in body_parts if part) + "\n" + NETSCAPE_FOOTER


def convert_bookmarks(source_json_path, dest_html_path):
    try:
        with open(source_json_path, encoding="utf-8") as handle:
            chrome_json = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        return False, str(exc)

    html_content = chrome_bookmarks_to_netscape_html(chrome_json)
    os.makedirs(os.path.dirname(dest_html_path), exist_ok=True)
    with open(dest_html_path, "w", encoding="utf-8") as handle:
        handle.write(html_content)
    return True, None


def copy_item(item, target_home, run=subprocess.run):
    """Copia um único item selecionado; nunca levanta exceção (§5: falha
    parcial não aborta a instalação — o chamador só olha o campo "ok").
    """
    dest_path = os.path.join(target_home, item["dest"])
    try:
        if item["kind"] == "directory":
            ok, error = rsync_copy(item["source_path"], dest_path, run=run)
        elif item["kind"] == "browser-bookmarks":
            if "__PROFILE__" in item["dest"]:
                dest_path = os.path.join(target_home, STAGING_BOOKMARKS_RELATIVE)
            ok, error = convert_bookmarks(item["source_path"], dest_path)
        else:
            ok, error = False, f"tipo de item desconhecido: {item['kind']}"
    except OSError as exc:
        ok, error = False, str(exc)

    return {"id": item["id"], "dest": dest_path, "ok": ok, "error": error}


def run_copy(migration, selection, target_home, run=subprocess.run):
    """Copia todos os itens selecionados; falha em um item não interrompe
    os demais (§5). Retorna o resumo salvo em globalstorage para a tela
    Finished (§6.2).
    """
    if not migration.get("found") or selection.get("skipped"):
        return {"skipped": True, "results": []}

    profile = selection["profile"]
    items_by_id = {item["id"]: item for item in migration["profiles"][profile]}

    results = []
    for item_id in selection.get("selectedIds", []):
        item = items_by_id.get(item_id)
        if item is None:
            continue
        results.append(copy_item(item, target_home, run=run))

    return {"skipped": False, "profile": profile, "results": results}

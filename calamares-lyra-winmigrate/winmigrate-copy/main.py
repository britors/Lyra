"""Glue Calamares do job de cópia (PROMPT-CALAMARES-MIGRACAO-WINDOWS.md §5).

Roda no bloco `exec` final da instalação, junto de unpackfs/users/etc,
depois que o job "users" já criou a conta do novo usuário. Lê o
resultado da detecção e a seleção feita na tela QML "winmigrate" em
globalstorage, executa a cópia e desmonta a partição NTFS ao final —
mantida montada desde winmigrate-detect (§5).
"""

import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))

import libcalamares

from jobs import copy_job


def pretty_name():
    return "Copiando seus arquivos do Windows..."


def run():
    migration = libcalamares.globalstorage.value("windowsMigration") or {"found": False}
    selection = libcalamares.globalstorage.value("windowsMigrationSelection") or {"skipped": True}

    if migration.get("found"):
        try:
            if not selection.get("skipped"):
                root_mount_point = libcalamares.globalstorage.value("rootMountPoint")
                username = libcalamares.globalstorage.value("username")
                target_home = os.path.join(root_mount_point, "home", username)

                summary = copy_job.run_copy(migration, selection, target_home)
                libcalamares.globalstorage.insert("windowsMigrationResult", summary)

                failures = [r for r in summary["results"] if not r["ok"]]
                for failure in failures:
                    libcalamares.utils.warning(
                        f"winmigrate-copy: falha ao copiar '{failure['id']}': {failure['error']}"
                    )
            else:
                libcalamares.globalstorage.insert("windowsMigrationResult", {"skipped": True, "results": []})
        finally:
            subprocess.run(["umount", migration["mountpoint"]], check=False)

    # Falha parcial de itens individuais nunca aborta a instalação (§5) —
    # este job só retorna erro (string) se a infraestrutura em si falhar,
    # o que não é o caso aqui.
    return None

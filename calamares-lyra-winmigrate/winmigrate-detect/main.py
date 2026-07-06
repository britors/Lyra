"""Glue Calamares do job de detecção (PROMPT-CALAMARES-MIGRACAO-WINDOWS.md §3).

Roda no bloco `exec` logo após o job `partition`, ou seja, com o
particionamento definitivo já aplicado no disco — a partição Windows
existe fisicamente e pode ser montada. Escreve o resultado em
globalstorage sob a chave `windowsMigration`, consumida pela tela QML
`winmigrate` (view) e, mais tarde, pelo job `winmigrate-copy`.

A montagem somente-leitura é deixada ativa propositalmente (§5): será
desmontada pelo job winmigrate-copy ao final da instalação.
"""

import os

import libcalamares
import yaml

import detection

MAPPING_PATH = "/etc/calamares/modules/winmigrate-mapping.conf"


def pretty_name():
    return "Procurando instalação do Windows"


def run():
    if not os.path.exists(MAPPING_PATH):
        libcalamares.utils.warning(f"winmigrate-detect: mapeamento não encontrado em {MAPPING_PATH}")
        libcalamares.globalstorage.insert("windowsMigration", {"found": False})
        return None

    with open(MAPPING_PATH, encoding="utf-8") as handle:
        mapping = yaml.safe_load(handle)

    result = detection.detect(mapping)
    libcalamares.globalstorage.insert("windowsMigration", result)

    if result["found"]:
        libcalamares.utils.debug(
            f"winmigrate-detect: Windows encontrado em {result['device']}, "
            f"perfis: {list(result['profiles'])}"
        )
    else:
        libcalamares.utils.debug("winmigrate-detect: nenhuma instalação Windows utilizável")

    return None

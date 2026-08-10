#!/usr/bin/env bash
# One-off remediation for machines installed before kiwi/root/etc/polkit-1/
# rules.d/51-lyra-wheel-admin.rules existed. Without it, polkit's
# _suse_admin_groups stays empty and every pkexec auth_admin action prompts
# for root's password - which is locked ("!" in kiwi/config.xml), making the
# prompt impossible to satisfy. This copies that same rule file onto an
# already-installed system and restarts polkit so it takes effect
# immediately. New ISOs already include it via the base image; this just
# patches a system installed before the fix landed.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_RULE="$SCRIPT_DIR/../kiwi/root/etc/polkit-1/rules.d/51-lyra-wheel-admin.rules"
DEST_RULE="/etc/polkit-1/rules.d/51-lyra-wheel-admin.rules"

if [[ ! -f "$SOURCE_RULE" ]]; then
    echo "erro: $SOURCE_RULE não encontrado - rode a partir de um checkout do repo Lyra" >&2
    exit 1
fi

sudo install -m 0644 "$SOURCE_RULE" "$DEST_RULE"
sudo systemctl restart polkit

echo
echo "Regra instalada em $DEST_RULE e polkit reiniciado."
echo "Teste com: pkexec whoami"
echo "Deve pedir a SUA senha (não a do root) e retornar 'root'."

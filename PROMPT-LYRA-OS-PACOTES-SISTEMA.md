# PROMPT DE IMPLEMENTAÇÃO — LYRA OS: PACOTES DE SISTEMA (restic, firewalld, fwupd)

> **Versão:** 1.0
> **Status:** Especificação incremental, pronta para implementação
> **Pré-requisitos:** `PROMPT-LYRA-OS.md` v2.1
> **Escopo:** Este documento adiciona explicitamente três pacotes de repositório oficial (`extra`) ao `packages.x86_64` do ISO — **restic**, **firewalld** e **fwupd**. Os três já eram pressupostos por especificações anteriores (Vega Backup, firewall do sistema, atualização de firmware), mas não estavam confirmados como entrada explícita na lista de pacotes do build. Este documento fecha essa lacuna.

---

## 1. Por que cada um

| Pacote | Já previsto em | Função |
|---|---|---|
| `restic` | `PROMPT-VEGA-MODULO-BACKUP.md` §2 | Motor de backup usado pelo módulo Backup do Vega (via subprocesso, orquestrado pelo `vegad`) |
| `firewalld` | `PROMPT-LYRA-OS.md` §3.4 | Firewall do sistema, já especificado como habilitado por padrão; módulo Firewall do Vega (`PROMPT-VEGA.md` §3.5) depende dele |
| `fwupd` | `PROMPT-VEGA.md` §3.3 | Atualização de firmware via LVFS, exposto no módulo Hardware e Drivers do Vega |

Nenhum dos três exige justificativa nova — são confirmações de dependências já assumidas em specs anteriores que precisavam virar linha real no `packages.x86_64`.

---

## 2. Alteração em `packages.x86_64`

```diff
+ restic
+ firewalld
+ fwupd
```

Todos os três vêm do repositório oficial `extra` — nenhuma alteração em `pacman.conf`, `setup-build-host.sh` ou `packages.aur.lock` é necessária (diferente dos pacotes AUR do ecossistema Lyra, estes são resolvidos normalmente pelo Pacman a partir dos repositórios já habilitados).

---

## 3. Serviços e Ativação

### 3.1 `firewalld`

- Já especificado como **habilitado por padrão** (`PROMPT-LYRA-OS.md` §3.4, zona `home`). Este documento apenas confirma o pacote na lista de build — nenhuma mudança em `build.sh` além de garantir que a linha de habilitação já prevista continue presente:

```
systemctl enable firewalld
```

### 3.2 `fwupd`

- **Não requer `systemctl enable` explícito** — o `fwupd.service` é ativado por D-Bus (bus activation), mesmo padrão de design já adotado para o `vegad` no ecossistema Vega. Sobe sob demanda quando o módulo Hardware do Vega (ou o `fwupdmgr` via terminal) o invoca, e encerra ocioso depois.
- **Não confundir com `systemctl enable`** no `build.sh` — apenas validar a presença do pacote e da unit no chroot, análogo ao que já é feito para `vegad.service`.

### 3.3 `restic`

- Ferramenta de linha de comando, sem serviço próprio — nenhuma unit systemd a habilitar. É invocada como subprocesso pelo `vegad` (via `systemd-run` com isolamento, conforme já especificado em `PROMPT-VEGA-MODULO-BACKUP.md` §4) apenas quando o usuário configura ou executa um backup pelo módulo Backup do Vega.

---

## 4. Validação

- [ ] `pacman -Qi restic firewalld fwupd` presentes na instalação limpa do Lyra OS
- [ ] `systemctl is-enabled firewalld` retorna `enabled`
- [ ] `systemctl status fwupd` reporta `inactive` logo após o boot (bus activation, não deve estar `enabled` explicitamente)
- [ ] `fwupdmgr get-devices` funciona sem erro (ativa o `fwupd` sob demanda)
- [ ] `restic version` funciona a partir de qualquer shell, confirmando que o binário está no `PATH` do sistema
- [ ] Nenhuma mudança inesperada em `pacman.conf` ou nos scripts de build — os três pacotes resolvem via `extra` sem configuração adicional

---

## 5. Fora de Escopo

- Configuração funcional do módulo Backup do Vega (já especificada em `PROMPT-VEGA-MODULO-BACKUP.md`) — este documento só garante o pacote presente no sistema
- Configuração de zonas/regras adicionais do `firewalld` além do já especificado (`PROMPT-LYRA-OS.md` §3.4, `PROMPT-VEGA.md` §3.5)
- Integração de firmware específico de hardware (LVFS já cobre o caso geral; hardware com necessidades especiais fica fora de escopo)

---

**Fim da especificação.**

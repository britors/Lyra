---
name: avaliacao-migracao-fedora-copr
description: Teste de uma semana do Fedora (a partir de 2026-08-22) que pode levar o Lyra OS a migrar de base openSUSE/zypper para Fedora/dnf e os pacotes para o COPR
metadata:
  type: project
---

Em 2026-08-22 o Rodrigo teve mais uma rodada de problemas com o zypper e decidiu
formatar a máquina para testar o Fedora (dnf) por cerca de uma semana
(avaliação até por volta de 2026-08-29).

**Critério de decisão:** se o computador funcionar melhor com Fedora/dnf, o plano
é migrar o Lyra OS da base atual (openSUSE, zypp/zypper) para base Fedora, e
migrar os pacotes de distribuição para o COPR.

**Why:** os atritos recorrentes com o zypper são o motivador; a decisão ainda não
está tomada, depende do resultado do teste de uma semana.

**How to apply:** enquanto o teste estiver em curso, tratar a base openSUSE como o
status quo e não reescrever packaging por conta própria. Ao retomar o assunto,
perguntar como foi a semana com Fedora antes de propor trabalho. Se a migração for
confirmada, o escopo inclui o packaging atual em zypp/zypper (diretórios zypp do
Lyra Upgrade, promoção de instalador, retenção de pacotes) que precisaria de
equivalente em RPM/dnf + COPR. Ver [[running-lyra-tauri-apps]] para o ambiente de
execução local, que também muda se a máquina for reformatada.

# Registros de decisão do Lyra Installer

Os ADRs deste diretório registram decisões aceitas do instalador. Uma decisão
nova não apaga a anterior: cria outro ADR que a substitui e aponta para ela.

| ADR | Decisão | Estado |
|---|---|---|
| [0001](0001-tauri-frontend-unprivileged.md) | Tauri/WebKitGTK como frontend sem privilégio | Aceita |
| [0002](0002-json-lines-privileged-protocol.md) | Protocolo JSON Lines e plano versionado | Aceita |
| [0003](0003-storage-tools-behind-typed-operations.md) | Ferramentas nativas atrás de operações tipadas | Aceita |
| [0004](0004-rust-installer-only-in-beta-2.md) | Instalador Rust como único caminho da Beta 2 | Aceita |
| [0005](0005-guided-swap-policy-and-plan-v2.md) | Política guiada de swap e plano versão 2 | Aceita |

Mudanças incompatíveis no formato do plano precisam incrementar
`INSTALL_PLAN_SCHEMA_VERSION`, atualizar o ADR 0002 por meio de um novo ADR e
adicionar testes de rejeição/compatibilidade antes de chegar ao serviço root.

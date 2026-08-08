# ADR 0003: ferramentas nativas atrás de operações tipadas

- Estado: aceita
- Data: 2026-08-08
- Issue: #35

## Contexto

O Leap já fornece utilitários maduros para GPT, Btrfs, RAID, LVM, boot e
snapshots. Adotar bindings diferentes para cada subsistema aumentaria o número
de APIs e diferenças em relação às ferramentas usadas na recuperação manual.
Ao mesmo tempo, concatenar comandos em uma shell seria inseguro.

## Decisão

Descoberta é somente leitura e usa `lsblk`, sysfs e relatórios JSON de LVM.
Execução usa implementações de `PrivilegedOperation` que produzem
`ArgvCommand`: binário e argumentos separados, nunca `sh -c`. Um único
`RealExecutor` aplica `ALLOWED_BINARIES` antes de criar processos.

E/S de arquivos do target é feita diretamente pelo serviço root em caminhos
derivados de constantes e tipos validados. Dados secretos destinados a
`chpasswd` seguem por stdin. Cada mount implementa `undo`, e o engine desfaz
operações concluídas em ordem reversa em sucesso, falha ou cancelamento.

## Consequências

- argv exato, ordem e rollback de mounts são cobertos por testes unitários;
- ferramentas disponíveis no ambiente live continuam sendo fonte operacional
  e caminho de diagnóstico;
- toda adição a `ALLOWED_BINARIES` exige revisão explícita;
- bibliotecas como libblockdev/udisks não são dependências do núcleo nesta
  fase; podem ser reconsideradas se oferecerem uma operação atômica ou
  observabilidade que as ferramentas atuais não forneçam;
- testes unitários não substituem o teste destrutivo em loop device/VM.

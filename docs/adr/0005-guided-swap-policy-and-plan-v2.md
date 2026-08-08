# ADR 0005: política guiada de swap e plano versão 2

- Estado: aceita
- Data: 2026-08-08

## Contexto

ZRAM era habilitada incondicionalmente pela imagem. O instalador precisava
permitir que a pessoa escolhesse entre não usar memória virtual, usar swap
persistente no disco ou manter ZRAM, sem deixar essa decisão apenas no estado
do frontend.

## Decisão

`GuidedChoice` passa a carregar `SwapChoice::{None, Disk, Zram}` e o
`InstallPlan` registra o resultado como `SwapPlan`. `Disk` reserva uma partição
de 8 GiB, executa `mkswap` e escreve seu UUID no `fstab`. `Zram` grava a
configuração do `zram-generator` com zstd; as outras escolhas removem essa
configuração. ZRAM permanece selecionada por padrão.

Como serviços antigos não conhecem o novo campo nem o particionamento extra,
`INSTALL_PLAN_SCHEMA_VERSION` passa de 1 para 2. Não existe migração de planos
destrutivos versão 1: frontend e serviço precisam ser atualizados juntos.

## Consequências

- o espaço da swap em disco é descontado antes de validar o mínimo da raiz;
- a escolha é exibida no plano e no resumo final e é revalidada pelo serviço;
- `mkswap` entra na allow-list privilegiada e `util-linux` permanece uma
  dependência explícita da imagem e do RPM;
- a opção sem swap é intencional e pode reduzir a tolerância à pressão de
  memória em máquinas com pouca RAM.

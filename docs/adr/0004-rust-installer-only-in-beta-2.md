# ADR 0004: instalador Rust como único caminho da Beta 2

- Estado: aceita
- Data: 2026-08-08
- Issues: #6, #35

## Contexto

O planejamento inicial tratava o instalador Rust como experimental e mantinha
um segundo instalador como padrão/fallback. A decisão de produto foi alterada:
a Beta 2 deve validar e apresentar um único caminho de instalação.

## Decisão

A ISO Beta 2 contém somente o RPM `lyra-installer`. Seu desktop entry e
autostart são os únicos launchers de instalação. Não existe fallback para
outro instalador, e os gates do Rust bloqueiam o release.

A configuração anterior fica em `docs/calamares-reference/` apenas para
auditoria histórica e não é copiada para `kiwi/root/`.

## Consequências

- #43 e #44 foram fechadas como supersedidas;
- #11 concentra instalação, primeiro boot, UEFI, Secure Boot e rollback;
- falha do instalador Rust impede a publicação da Beta 2;
- remover o fallback aumenta a importância de logs acionáveis, teste em
  hardware e recuperação segura;
- a ISO pode ser construída durante o desenvolvimento, mas não promovida sem
  o gate end-to-end verde.

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

Configurações e assets do instalador anterior foram removidos do repositório e
dos projetos OBS.

## Consequências

- #43 e #44 foram fechadas como supersedidas;
- a instalação manual foi validada; o candidato final registra primeiro boot,
  UEFI, Secure Boot e rollback em #51;
- #11 acompanha a automação end-to-end futura na Beta 3;
- falha do instalador Rust impede a publicação da Beta 2;
- remover o fallback aumenta a importância de logs acionáveis, teste em
  hardware e recuperação segura;
- a ISO pode ser construída durante o desenvolvimento, mas não promovida sem
  as evidências manuais do candidato final.

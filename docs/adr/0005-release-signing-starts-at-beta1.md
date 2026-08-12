# ADR 0005: assinatura de artefatos começa na Beta 1

- Status: aceita
- Data: 2026-08-12
- Escopo: Lyra OS Desktop Alpha 3 e releases posteriores

## Contexto

A Desktop Alpha 3 possui ISO rastreável, SHA-256, inventário de pacotes,
relatório KIWI e SBOMs, mas a chave privada correspondente à identidade GPG
anteriormente documentada não está disponível no chaveiro de release. Criar
uma chave descartável apenas para esta Alpha produziria uma cadeia de confiança
curta, exigiria rotação imediata e poderia induzir usuários a tratar uma chave
temporária como identidade permanente do projeto.

As assinaturas dos repositórios e pacotes RPM são independentes da assinatura
da ISO e continuam obrigatórias. Esta decisão não reduz `repository_gpgcheck`,
`package_gpgcheck`, a verificação dos RPMs do OBS ou a validação do SquashFS.

## Decisão

1. A Desktop Alpha 3 será publicada no SourceForge com SHA-256 verificável,
   manifesto de origem, inventário, relatório e SBOMs, sem `*.iso.sha256.asc`.
2. A ausência da assinatura será declarada nas notas, no gate e no script de
   publicação; não será ocultada nem substituída por assinatura improvisada.
3. Nenhuma nova chave de release será criada durante as Alphas.
4. Antes do primeiro candidato Beta 1 ocorrerá uma cerimônia de chave:
   - criar uma chave de release duradoura em ambiente controlado;
   - definir expiração e política de rotação;
   - produzir backup privado offline e certificado de revogação;
   - publicar e conferir o fingerprint por mais de um canal;
   - atualizar a chave pública, documentação e automação no mesmo commit;
   - ensaiar assinatura, verificação, revogação e recuperação do backup.
5. Beta 1 e todas as versões posteriores exigirão assinatura destacada do
   checksum para publicação. Ausência ou fingerprint divergente será P1.

## Consequências

- A Alpha 3 oferece integridade por SHA-256, mas não autenticidade criptográfica
  da ISO; usuários devem obter o checksum pelo canal oficial e entender essa
  limitação de uma versão Alpha.
- Evita-se estabelecer uma identidade GPG temporária e descartável.
- A Beta 1 ganha um requisito de entrada explícito e bloqueante para gestão de
  chaves, além do congelamento funcional já previsto.
- A política pode ser endurecida antes da Beta 1, mas não relaxada depois dela
  sem uma nova ADR e decisão formal de segurança.

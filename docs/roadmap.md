# Roadmap do Lyra OS

## Lyra OS Desktop Alpha 4 e Alpha 5

A Alpha 4 (01/09/2026–22/09/2026) cria a infraestrutura de i18n, entrega o
Lyra Installer e a primeira onda de pacotes em `pt-BR`/`en-US`, e adiciona ao
Vega o fluxo opcional pós-instalação para drivers NVIDIA proprietários. A Alpha
5 (22/09/2026–13/10/2026) conclui a internacionalização de todos os pacotes
próprios, integra os RPMs e encerra o desenvolvimento de features da 1.0.

O gate da funcionalidade exige detecção conservadora de hardware compatível,
confirmação explícita, Secure Boot verificado, snapshot Snapper antes da
mudança, pacotes meta que mantenham KMP, userspace e firmware em lockstep,
`dracut`, reinício orientado e rollback documentado. A Alpha 4 não pode ser
promovida com um P1 aberto nesse fluxo.

## Lyra OS Server 1.0

O Server segue um ciclo independente com a mesma cadência e os mesmos gates
P0–P3 do Desktop. A Alpha 1 atual vai até 01/09/2026; Alpha 2 e uma Alpha 3
opcional ocupam as janelas seguintes. O alvo antecipado da final é
aproximadamente 26/01/2027, com buffer até aproximadamente 16/02/2027. O
cronograma detalhado e os critérios de saída estão em
[`release-versioning.md`](release-versioning.md#lyra-os-server-10).

## Ciclo pós-release

A instalação opcional via Vega pertence à Desktop Alpha 4, mas a ISO com o
driver proprietário NVIDIA pré-instalado e configurado continua sendo um
deliverable planejado para depois da publicação da Lyra OS 1.0. O alvo interno
da versão final é aproximadamente 26/01/2027, com buffer até aproximadamente
16/02/2027, conforme o cronograma canônico em
[`release-versioning.md`](release-versioning.md). O rascunho de arquitetura, incluindo as
questões em aberto que bloqueiam o início da implementação (rota de Secure
Boot, proveniência do pacote do driver, escopo de laptops híbridos e política
de lockstep kernel+kmp), está em [`nvidia-iso.md`](nvidia-iso.md).

## Congelamento funcional a partir da Beta 1

A Beta 1 começa em 13/10/2026 com todas as features e a infraestrutura de i18n
fechadas. Beta 1, Beta 2, Beta 3 e RCs não recebem novas features.

São permitidas somente correções de bugs, regressões, segurança, desempenho e
traduções já existentes. A Beta 3 faz QA linguístico e corrige catálogos, mas
não cria infraestrutura, não incorpora um novo pacote ao esforço e não adiciona
idioma. Exceções exigem um P0/P1 e decisão formal registrada.

O cronograma semanal, o inventário nominal de pacotes e os critérios de saída
estão em [`release-versioning.md`](release-versioning.md#desktop-alpha-4--0109-a-2209).

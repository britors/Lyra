# Roadmap do Lyra OS

## Lyra OS Desktop Alpha 4 a Alpha 8

A Alpha 4 será publicada em 14/08/2026 como snapshot antecipado da
infraestrutura de i18n, do Lyra Installer em
`en-US`/`pt-BR`/`es-ES`/`zh-CN` e da primeira onda de pacotes em
`pt-BR`/`en-US`. A Alpha 5 (14–28/08) conclui a internacionalização restante,
fecha NVIDIA e especifica o Lyra Upgrade. A Alpha 6 (28/08–11/09) integra os
RPMs e entrega core e serviço de update. A Alpha 7 (11–25/09) entrega interface,
pós-boot, recuperação e rollback. A Alpha 8 (25/09–13/10) fecha o upgrade entre
releases, automatiza o gate e reserva a última semana para estabilização. A
Beta 1 não começa por calendário com P0/P1 ou entrega obrigatória pendente.
O instalador da 1.0 oferece inglês dos Estados Unidos (`en-US`), português do
Brasil (`pt-BR`), espanhol da Espanha (`es-ES`) e chinês simplificado
(`zh-CN`), com `en-US` como padrão e fallback. Para os demais pacotes próprios,
o gate integral permanece fechado em `en-US`/`pt-BR`.

O gate da funcionalidade exige detecção conservadora de hardware compatível,
confirmação explícita, Secure Boot verificado, snapshot Snapper antes da
mudança, pacotes meta que mantenham KMP, userspace e firmware em lockstep,
`dracut`, reinício orientado e rollback documentado. O fluxo não pode ser
declarado suportado com um P1 aberto; a pendência da Alpha 4 fica registrada
explicitamente na Alpha 5.

## Lyra OS Server 1.0 “Delos”

O Server 1.0 usa o codinome **Delos** e segue um ciclo independente com a
mesma cadência e os mesmos gates
P0–P3 do Desktop. A Alpha 1 atual vai até 01/09/2026; Alpha 2 e uma Alpha 3
opcional ocupam as janelas seguintes. O alvo antecipado da final é
aproximadamente 26/01/2027, com buffer até aproximadamente 16/02/2027. O
cronograma detalhado e os critérios de saída estão em
[`release-versioning.md`](release-versioning.md#lyra-os-server-10).

O ciclo seguinte será o **Lyra OS Server 1.1 “Tebas”**, baseado no openSUSE
Leap 16.1. Ele começa em 01/03/2027 e mantém gate independente: três Alphas
de três semanas, três Betas de quatro semanas, duas RCs de duas semanas e
buffer de duas semanas para a final estável, prevista para aproximadamente
06/09/2027.

## Ciclo pós-release

A instalação opcional via Vega pertence à Desktop Alpha 5, mas a ISO com o
driver proprietário NVIDIA pré-instalado e configurado continua sendo um
deliverable planejado para depois da publicação da Lyra OS 1.0. O alvo interno
da versão final é aproximadamente 26/01/2027, com buffer até aproximadamente
16/02/2027, conforme o cronograma canônico em
[`release-versioning.md`](release-versioning.md). O rascunho de arquitetura, incluindo as
questões em aberto que bloqueiam o início da implementação (rota de Secure
Boot, proveniência do pacote do driver, escopo de laptops híbridos e política
de lockstep kernel+kmp), está em [`nvidia-iso.md`](nvidia-iso.md).

## Congelamento funcional a partir da Beta 1

A Beta 1 tem 13/10/2026 como meta e começa somente com todas as features e a
infraestrutura de i18n fechadas. Beta 1, Beta 2, Beta 3 e RCs não recebem novas
features. Alpha 5, Alpha 6, Alpha 7 e Alpha 8 são etapas obrigatórias; se
necessário, a fase Alpha continua além de 13/10 em vez de reduzir os gates.

São permitidas somente correções de bugs, regressões, segurança, desempenho e
traduções já existentes. A Beta 3 faz QA linguístico e corrige catálogos, mas
não cria infraestrutura, não incorpora um novo pacote ao esforço e não adiciona
idioma. Exceções exigem um P0/P1 e decisão formal registrada.

O cronograma semanal, o inventário nominal de pacotes e os critérios de saída
estão em [`release-versioning.md`](release-versioning.md#cronograma-do-ciclo-lyra-os-10).

## Idiomas na versão 1.1

A ampliação para outros idiomas começa somente no ciclo Lyra OS 1.1. A
infraestrutura criada na 1.0 deve aceitar novos catálogos com fallback para
`en-US`, mas isso não autoriza publicar traduções adicionais antes da 1.1.
Cada novo idioma terá inventário, revisão humana, fallback e gate linguístico
próprios antes de ser oferecido pelo instalador.

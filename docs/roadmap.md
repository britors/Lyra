# Roadmap do Lyra OS

## Lyra Enterprise Linux

Fica registrada a decisão de criar futuramente o **Lyra Enterprise Linux**
nas edições **Desktop** e **Server**, ambas baseadas no **SUSE Linux
Enterprise**. Esta decisão não altera o escopo nem a base dos ciclos atuais do
Lyra OS; planejamento, versões e cronograma serão definidos separadamente.

## Lyra OS Desktop Alpha 4 a Alpha 8

A Alpha 4 foi publicada em 14/08/2026 como snapshot antecipado da
infraestrutura de i18n, do Lyra Installer em `en-US`/`pt-BR`/`es-ES` e da
primeira onda de pacotes em `pt-BR`/`en-US`.

- **Alpha 5 (14–28/08) — estabilização e contratos:** corrige os bloqueadores
  herdados do instalador e do release e especifica o Lyra Upgrade. Os três
  idiomas e o fluxo NVIDIA pelo Vega já estão concluídos e validados.
- **Alpha 6 (28/08–11/09) — backend:** entrega core, preflight, estado durável,
  serviço privilegiado e atualização segura dentro da mesma release.
- **Alpha 7 (11–25/09) — produto completo:** entrega a interface e o upgrade
  controlado entre releases. A recuperação pós-boot e o rollback já foram
  validados antecipadamente.
- **Alpha 8 (25/09–13/10) — gate e estabilização:** automatiza update, upgrade,
  reboot e rollback; depois corrige somente defeitos até a decisão da Beta 1.

A Beta 1 não começa por calendário com P0/P1 ou entrega obrigatória pendente.
O Lyra OS 1.0 oferece somente inglês dos Estados Unidos (`en-US`), português
do Brasil (`pt-BR`) e espanhol da Espanha (`es-ES`), com `en-US` como padrão e fallback.
Os projetos e seus RPMs já foram traduzidos e testados nos três idiomas.
Outros idiomas entram apenas em ciclo futuro.

O gate da funcionalidade exige detecção conservadora de hardware compatível,
confirmação explícita, Secure Boot verificado, snapshot Snapper antes da
mudança, pacotes meta que mantenham KMP, userspace e firmware em lockstep,
`dracut`, reinício orientado e rollback documentado. O fluxo não pode ser
declarado suportado com um P1 aberto; a pendência da Alpha 4 fica registrada
explicitamente na Alpha 5.

## Lyra OS Server 1.0 “Delos”

O Server 1.0 usa o codinome **Delos** e segue um ciclo independente com a
mesma cadência e os mesmos gates
P0–P3 do Desktop. Em 15/08/2026 o mantenedor encerrou antecipadamente o
desenvolvimento funcional e promoveu o ciclo diretamente para Beta 1. As
correções bloqueantes já identificadas e o fechamento das evidências
ocupam esta etapa; nenhuma feature nova será aceita. O plano anterior da
Alpha 3 foi absorvido pela estabilização da Beta 1. O alvo antecipado da final é
aproximadamente 26/01/2027, com buffer até aproximadamente 16/02/2027. O
cronograma detalhado e os critérios de saída estão em
[`release-versioning.md`](release-versioning.md#lyra-os-server-10).

O ciclo seguinte será o **Lyra OS Server 1.1 “Tebas”**, baseado no openSUSE
Leap 16.1. Ele começa em 01/03/2027 e mantém gate independente: três Alphas
de três semanas, três Betas de quatro semanas, duas RCs de duas semanas e
buffer de duas semanas para a final estável, prevista para aproximadamente
06/09/2027.

## NVIDIA em uma única ISO Desktop

A ISO NVIDIA dedicada foi cancelada. A instalação opcional via Vega foi
concluída na Desktop Alpha 5 e é o único fluxo proprietário: detecção do
hardware real, confirmação, verificação de Secure Boot, snapshot Snapper,
pacotes KMP/userspace em lockstep, `dracut`, reinício, validação e rollback.
As descobertas técnicas preservadas em [`nvidia-iso.md`](nvidia-iso.md) são
históricas e alimentam esse fluxo; não representam uma segunda imagem.

## Congelamento funcional a partir da Beta 1

A Server Beta 1 foi iniciada antecipadamente em 15/08/2026 por decisão do
mantenedor, com o escopo funcional encerrado. A Desktop Beta 1 mantém
13/10/2026 como meta; Alpha 5, Alpha 6, Alpha 7 e Alpha 8 continuam etapas
obrigatórias do Desktop. Em ambas as edições, Betas e RCs não recebem novas
features e os gates não são reduzidos para cumprir calendário.

São permitidas somente correções de bugs, regressões, segurança, desempenho e
traduções já existentes. A Beta 3 faz QA linguístico e corrige catálogos, mas
não cria infraestrutura, não incorpora um novo pacote ao esforço e não adiciona
idioma. Exceções exigem um P0/P1 e decisão formal registrada.

O cronograma semanal, o inventário nominal de pacotes e os critérios de saída
estão em [`release-versioning.md`](release-versioning.md#cronograma-do-ciclo-lyra-os-10).

## Idiomas em ciclos futuros

A ampliação para outros idiomas começa somente depois da Lyra OS 1.0. A
infraestrutura criada na 1.0 deve aceitar novos catálogos com fallback para
`en-US`, mas isso não autoriza publicar traduções adicionais antes da 1.1.
Cada novo idioma terá inventário, revisão humana, fallback e gate linguístico
próprios antes de ser oferecido pelo instalador.

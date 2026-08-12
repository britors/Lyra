# Roadmap do Lyra OS

## Lyra OS Server 1.0

O Server segue um ciclo independente com a mesma cadência e os mesmos gates
P0–P3 do Desktop. A Alpha 1 atual vai até 01/09/2026; Alpha 2 e uma Alpha 3
opcional ocupam as janelas seguintes. O alvo antecipado da final é
aproximadamente 26/01/2027, com buffer até aproximadamente 16/02/2027. O
cronograma detalhado e os critérios de saída estão em
[`release-versioning.md`](release-versioning.md#lyra-os-server-10).

## Ciclo pós-release

A ISO com o driver proprietário NVIDIA pré-instalado e configurado é um
deliverable planejado para depois da publicação da Lyra OS 1.0. O alvo interno
da versão final é aproximadamente 26/01/2027, com buffer até aproximadamente
16/02/2027, conforme o cronograma canônico em
[`release-versioning.md`](release-versioning.md). O rascunho de arquitetura, incluindo as
questões em aberto que bloqueiam o início da implementação (rota de Secure
Boot, proveniência do pacote do driver, escopo de laptops híbridos e política
de lockstep kernel+kmp), está em [`nvidia-iso.md`](nvidia-iso.md).

## Beta 3

A meta principal da Beta 3 é a **internacionalização (i18n) dos pacotes
próprios do ecossistema Lyra**.

No cronograma atual, a Beta 3 ocorre de 08/12/2026 a 05/01/2027. A promoção
continua condicionada ao fechamento dos bloqueadores das fases anteriores; a
data não reduz os gates de qualidade.

O ciclo deve preparar os pacotes mantidos pelo projeto para separar textos do
código, manter catálogos de tradução e oferecer fallback previsível quando uma
tradução não estiver disponível. O inventário dos pacotes, os idiomas
prioritários e os critérios de conclusão serão definidos no planejamento da
Beta 3.

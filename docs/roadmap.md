# Roadmap do Lyra OS

## Ciclo pós-release

A ISO com o driver proprietário NVIDIA pré-instalado e configurado é um
deliverable planejado para depois do lançamento da versão final (20/09/2026),
conforme `PROMPT-LYRA-OS.md`. O rascunho de arquitetura, incluindo as
questões em aberto que bloqueiam o início da implementação (rota de Secure
Boot, proveniência do pacote do driver, escopo de laptops híbridos e política
de lockstep kernel+kmp), está em [`nvidia-iso.md`](nvidia-iso.md).

## Beta 3

A meta principal da Beta 3 é a **internacionalização (i18n) dos pacotes
próprios do ecossistema Lyra**.

O ciclo deve preparar os pacotes mantidos pelo projeto para separar textos do
código, manter catálogos de tradução e oferecer fallback previsível quando uma
tradução não estiver disponível. O inventário dos pacotes, os idiomas
prioritários e os critérios de conclusão serão definidos no planejamento da
Beta 3.

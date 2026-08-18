# Dossiê preparatório para o parecer do ECA Digital

Status: **rascunho técnico para revisão jurídica — não é parecer jurídico**  
Issue: #106  
Baseline consultada: 18/08/2026

## Finalidade e limite

Este documento organiza fatos, componentes, hipóteses e perguntas que precisam
ser validados por profissional especializado em tecnologia, infância e proteção
de dados. Ele não conclui o enquadramento jurídico do Lyra, do mantenedor, do
Vega, do openSUSE, do OBS ou do Flathub e não autoriza aferição de idade.

Até a assinatura do parecer e a aprovação da ADR #111:

- não coletar documento, biometria, data de nascimento ou histórico de navegação;
- não tratar autodeclaração, declaração parental ou tipo da conta como aferição
  confiável;
- não liberar conteúdo ou instalação por ausência de sinal;
- não expor faixa etária por uma API geral;
- não selecionar fornecedor ou mecanismo proprietário;
- não implementar o serviço #114 nem a integração #109.

## Baseline normativa oficial

- A [Lei nº 15.211/2025](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2025/lei/l15211.htm)
  inclui programas, sistemas operacionais e lojas de aplicações no conceito de
  produto ou serviço de tecnologia da informação. O escopo considera direção
  ao público jovem ou acesso provável, e a lei veda solução que resulte em
  vigilância massiva, genérica ou indiscriminada.
- O [Decreto nº 12.880/2026](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2026/decreto/d12880.htm)
  regulamenta a lei e atribui à ANPD sua regulamentação e fiscalização, sem
  excluir competências de outros órgãos.
- A [página temática da ANPD](https://www.gov.br/anpd/pt-br/assuntos/eca-digital)
  registra a entrada em vigor, as orientações e o cronograma regulatório.
- As [orientações preliminares de aferição](https://www.gov.br/anpd/pt-br/assuntos/eca-digital/mecanismos-confiaveis-de-afericao-de-idade-orientacoes-preliminares.pdf)
  são a referência institucional vigente, mas estavam submetidas a atualização
  e não substituem o parecer específico do projeto.
- A ANPD [iniciou monitoramento de lojas e sistemas operacionais](https://www.gov.br/anpd/pt-br/assuntos/noticias/anpd-monitoramento-lojas-aplicativos-sistemas-operacionais)
  e descreve o sinal etário por interface segura e com proteção de privacidade.

## Produtos e relações técnicas a examinar

| Elemento | Papel factual no Lyra | Hipótese jurídica a validar |
|---|---|---|
| Lyra OS Desktop | Seleciona, integra e publica uma distribuição baseada no openSUSE | Se o projeto/mantenedor é fornecedor, em quais territórios e sob quais condições de oferta |
| openSUSE Leap | Base, pacotes, zypper, libzypp, AccountsService e mecanismos de segurança | Limites de responsabilidade da base upstream sem presumir transferência integral |
| Vega/vegad | Interface e serviço que pesquisam, instalam e atualizam software | Se o fluxo constitui loja de aplicações e quais obrigações próprias decorrem disso |
| OBS | Infraestrutura de build e publicação de RPMs | Papel de operador técnico versus fornecedor/distribuidor |
| Repositórios oficiais e Packman | Origens de RPM consumidas pelo produto | Responsabilidade por metadados, classificação, conteúdo e cadeia de distribuição |
| Flatpak/Flathub | Canal adicional de aplicações no desktop | Divisão entre loja, remoto, frontend e fornecedor de cada aplicação |
| Aplicativos | Produtos executados sobre o sistema | Deveres do fornecedor do aplicativo e sinal mínimo que poderia receber |
| Administrador/responsável | Configura contas e autoriza ações locais | Poderes, deveres e limites; declaração parental não presumida como aferição |
| Usuário supervisionado | Usa conta e dispositivo compartilhado ou individual | Direitos, autonomia progressiva, contestação, retificação, revogação e recuperação |

## Matriz preliminar requisito → componente → evidência → risco

| Tema normativo | Componentes possivelmente alcançados | Evidência técnica requerida | Risco se a hipótese estiver errada |
|---|---|---|---|
| Acesso provável por crianças e adolescentes | Lyra Desktop, Vega e catálogo de software | Público-alvo, telemetria inexistente, documentação, facilidade de acesso e conteúdo oferecido | Excluir indevidamente o produto do escopo |
| Qualificação como sistema operacional | Lyra Desktop | Arquitetura, marca, mídia de instalação, controle de release e atualização | Atribuir obrigação somente ao openSUSE |
| Qualificação do Vega como loja | Vega, vegad, zypper e Flatpak | Fluxos de busca, catálogo, download, instalação, autorização e origens | Omitir classificação, consentimento ou sinal no ponto relevante |
| Aferição confiável | Futuro serviço de políticas e eventual aferidor | Método, acurácia, proporcionalidade, fallback, fraude, compartilhamento do dispositivo | Coleta excessiva ou liberação indevida |
| Sinal etário interoperável | Serviço de políticas, Vega e consumidores autorizados | API de limiar/faixa, autenticação, consentimento, revogação e auditoria mínima | Correlação entre aplicativos ou revelação desnecessária |
| Supervisão parental | AccountsService, malcontent, serviço e Vega | Papéis, persistência, enforcement sem GUI, recuperação e autonomia progressiva | Controle aparente que possa ser contornado facilmente |
| Instalação de aplicativos | vegad, zypper, Flatpak e canais suportados | Classificação antes da autorização e cobertura de chamadas indiretas | Bypass por CLI, frontend alternativo ou canal não mediado |
| Minimização e retenção | Estado do serviço e logs | Inventário campo a campo, prazo, finalidade, exclusão e backup | Base de vigilância ou retenção sem finalidade |
| Transparência e direitos | Vega, documentação e suporte | Avisos, contestação, retificação, recuperação, revogação e canal de contato | Ausência de mecanismo efetivo para titular/responsável |
| Segurança e prevenção | Serviço, polkit, D-Bus, pacotes e update | Modelo de ameaça, testes, atualização, rollback e resposta a incidente | Salvaguarda removida por crash, downgrade ou elevação de privilégio |
| Responsabilidade compartilhada | Lyra, openSUSE, Flathub, OBS e fornecedores | Termos, controle efetivo de cada etapa e contatos | Lacuna entre agentes ou transferência contratual inválida |

## Perguntas obrigatórias ao parecerista

1. Quem é o fornecedor do Lyra quando a imagem é oferecida gratuitamente pelo
   projeto, por um espelho ou por terceiro? Marca, ausência de empresa e licença
   livre alteram quais deveres?
2. O uso provável do Desktop por crianças/adolescentes está caracterizado pelos
   critérios legais, ainda que o produto não seja dirigido especificamente a eles?
3. O Vega se enquadra como loja quando agrega resultados e inicia instalações
   de RPM e Flatpak? A resposta muda entre cada origem ou entre GUI e CLI?
4. Quais obrigações pertencem ao sistema, à loja, ao fornecedor da aplicação e
   ao responsável? Quais são solidárias ou não podem ser transferidas?
5. A edição comunitária sem conta central pode fornecer sinal local? Em quais
   condições declaração do responsável é somente configuração e não aferição?
6. Quais bases legais e garantias seriam necessárias para cada dado mínimo?
7. Qual deve ser o comportamento seguro na ausência de sinal confiável, em
   dispositivo compartilhado, offline, após perda de credenciais ou contestação?
8. É aceitável fornecer apenas respostas por limiar (`acima de N`) em vez da
   faixa? Quem pode solicitar, como registrar consentimento e como impedir
   correlação entre aplicativos?
9. Quais termos, política de privacidade, representação legal no Brasil, canal
   de contato e registro de evidências o projeto precisa manter?
10. Quais orientações definitivas ou atos futuros da ANPD constituem condição
    de reavaliação antes da Beta 1 ou da versão final?

## Evidências a entregar ao profissional

- diagramas do Lyra, Vega, zypper/Flatpak e fronteiras privilegiadas;
- lista de repositórios, mantenedores, licenças, termos e regiões de oferta;
- gravação dos fluxos de busca, detalhe, instalação e atualização;
- inventário preliminar de dados — inclusive confirmação explícita de dados que
  não são coletados;
- modelo de contas e capacidades administrativas;
- resultados da auditoria #112 e qualificação upstream #110;
- especificação de UX #108, sem assumir que ela cumpre a lei;
- modelo de ameaça e proposta de retenção da futura ADR #111.

## Candidato identificado para a revisão

O [Peck Advogados](https://peckadv.com.br/) foi identificado em 18/08/2026 como
candidato a receber este dossiê. A qualificação preliminar se apoia em material
publicado pelo próprio escritório sobre o ECA Digital, aferição de idade,
sistemas operacionais, lojas de aplicativos, proteção de dados e consultoria
digital. Isso demonstra aderência temática, mas não constitui seleção,
recomendação independente nem validação da qualidade do futuro parecer.

Antes da contratação, solicitar:

- identificação e currículo dos profissionais que assinarão o parecer;
- experiência comprovável em ECA Digital, LGPD, infância e produtos de software;
- confirmação de independência e verificação de conflitos com fornecedores de
  aferição etária, lojas, plataformas e demais agentes analisados;
- escopo fechado que responda a todas as perguntas obrigatórias e entregue a
  matriz revisada, riscos, condicionantes e validade temporal;
- tratamento confidencial das evidências técnicas e regras de descarte;
- preço, prazo, rodadas de esclarecimento e responsabilidade por atualização
  diante de nova regulamentação da ANPD.

Também convém comparar ao menos uma segunda proposta especializada. A decisão
de contratação e o parecer assinado permanecem atos externos ao repositório.

## Gate de conclusão da #106

A issue só pode ser fechada quando houver parecer datado e identificado,
matriz revisada, posição fundamentada sobre o Vega, lacunas bloqueantes e
processo de revisão normativa. O aceite deve registrar claramente quais pontos
são conclusão profissional, quais permanecem incertos e a validade temporal da
análise.

# Experiência de supervisão parental no Vega

Status: especificação de UX da #108 — implementação visual pertence à #109  
Idiomas obrigatórios: `en-US`, `pt-BR`, `es-ES`  
Fallback: `en-US`

## Princípios

1. **Proteção real, sem promessa excessiva.** A interface distingue política
   aplicada, camada complementar, limitação conhecida e falha.
2. **Privacidade por padrão.** Não mostrar faixa, histórico ou pedidos a quem
   não tenha capacidade explícita; não coletar atividade apenas para preencher
   gráficos.
3. **Autonomia progressiva.** Informação e possibilidade de pedido aumentam
   conforme a capacidade do usuário; isso não desativa proteção sozinho.
4. **Sem padrão manipulativo.** Ativar e desativar têm linguagem, esforço e
   confirmação proporcionais. Urgência não é usada para obter consentimento.
5. **Responsável não é aferidor.** Uma seleção declarada aparece como
   “informada pelo responsável”, nunca “idade verificada”.
6. **Enforcement fora da GUI.** Fechar ou remover o Vega não altera políticas.

## Navegação

O Vega recebe a seção **Família e supervisão**, visível somente quando o
backend estiver qualificado. Ela possui quatro destinos:

```text
Família e supervisão
├── Visão geral
├── Aplicativos
├── Tempo de uso
└── Privacidade e pedidos
```

“Atividade detalhada” não é destino inicial. Se futura decisão aprovar coleta,
ela aparece dentro de Privacidade, desativada por padrão e com finalidade,
retenção e campos explícitos.

## Estados globais

| Estado | Apresentação | Ações permitidas |
|---|---|---|
| Não configurado | Explica finalidade, dados e limitações | Iniciar configuração |
| Ativo e íntegro | Selo “Supervisão ativa”, última aplicação e resumo | Consultar/alterar conforme papel |
| Alteração pendente | Mostra autor, escopo e confirmação necessária | Confirmar ou descartar |
| Parcialmente aplicado | Aviso persistente com camadas afetadas | Reparar, diagnosticar; não afirmar proteção total |
| Backend indisponível | Estado bloqueado, política anterior preservada | Diagnóstico e recuperação |
| Estado corrompido/desconhecido | Alerta crítico e fail-closed | Recuperar snapshot/configuração |
| Contestação aberta | Exibe prazo/status sem revelar conteúdo indevido | Consultar e responder conforme papel |

## Fluxo 1 — iniciar supervisão

### Etapa 1: escolher uma conta

- listar contas padrão existentes;
- oferecer criação de nova conta padrão;
- impedir selecionar `root`, conta de sistema ou o único administrador;
- explicar que converter conta existente pode afetar aplicativos e sessões.

### Etapa 2: definir papéis

- mostrar administrador técnico e responsável como papéis distintos;
- exigir autenticação do responsável autorizado;
- não presumir que todo membro de `wheel` pode consultar dados pessoais;
- permitir recuperação por outro responsável somente se previamente definido.

### Etapa 3: sinal etário

Esta etapa é um slot condicionado à ADR #111. Até o contrato ser aprovado, o
protótipo mostra:

> O método de confirmação de idade ainda não está disponível. Nenhuma idade ou
> documento será solicitado nesta versão.

Quando existir, mostrar origem, nível de confiança, validade, dados tratados,
consumidores autorizados e forma de revogar/retificar. Nunca exibir data de
nascimento exata.

### Etapa 4: proteção inicial

Selecionar o perfil mais protetivo aplicável e apresentar, antes de confirmar:

- instalações que exigirão autorização;
- categorias OARS indisponíveis;
- agenda/tempo, se suportados;
- limitações de ACL, DNS, navegadores, VPN, AppImage e containers;
- dados que serão gravados e retenção.

O botão final é **Ativar supervisão**, acompanhado de autenticação. Não usar
caixa pré-marcada para coleta opcional.

### Etapa 5: verificação

Após aplicar, consultar novamente cada adaptador. Só mostrar “ativa” se o
backend comprovar persistência e enforcement. Falha parcial leva ao estado
“Precisa de atenção”, com opção de rollback da configuração.

## Fluxo 2 — visão do responsável

```text
┌ Conta: Ana                         Supervisão ativa ┐
│ Aplicativos: autorização necessária               │
│ Tempo: agenda ativa · quota não configurada        │
│ Rede: proteção complementar · limitações           │
│ Dados: somente configuração                        │
├ Pedidos pendentes (2)                              │
│ Aplicativo X                         [Revisar]      │
│ Alterar horário de sábado             [Revisar]      │
├ Estado do sistema                                  │
│ Todas as políticas obrigatórias aplicadas          │
└ [Alterar configurações] [Privacidade] [Diagnóstico]┘
```

Resumo não exibe histórico sensível por padrão. Pedidos mostram justificativa
do usuário supervisionado somente ao responsável autorizado.

## Fluxo 3 — visão do usuário supervisionado

Um indicador persistente na sessão abre uma página somente leitura:

- quem administra a supervisão e como contatar;
- controles ativos em linguagem adequada;
- quais dados são registrados, finalidade e prazo;
- limitações reais da proteção;
- pedidos enviados e respectivas decisões;
- **Pedir aplicativo**, **Pedir mais tempo** e **Contestar informação**;
- ajuda imediata e canal de suporte quando aplicável.

Não esconder supervisão. Não usar linguagem de culpa, ameaça ou vigilância.
Exemplo pt-BR:

> Esta conta usa regras definidas pelo seu responsável. O sistema registra as
> configurações necessárias para aplicá-las. Ele não registra seu histórico de
> navegação. Você pode pedir uma mudança ou corrigir uma informação.

## Fluxo 4 — instalação no Vega

Ao abrir um aplicativo:

1. Vega obtém classificação, origem e política do backend;
2. ausência/divergência de classificação é mostrada explicitamente;
3. se permitido, segue o fluxo normal;
4. se exigir responsável, o usuário pode enviar pedido com justificativa
   opcional;
5. o responsável vê nome, origem, classificação, permissões, preço e
   consequências antes de autorizar;
6. autorização é específica para aplicativo/origem/versão ou regra claramente
   descrita, nunca consentimento genérico escondido;
7. vegad revalida autorização na operação privilegiada.

CLI e chamadas indiretas devem receber código estruturado `AuthorizationRequired`
e não contornar o fluxo. A tela explica que bloquear o ícone não é proteção.

## Fluxo 5 — tempo de uso

Separar três conceitos:

- **agenda**: horários em que a sessão pode ser iniciada/usada;
- **quota**: duração consolidada por período;
- **atividade**: dado opcional e mais invasivo, não necessário por definição.

Avisar o usuário antes do encerramento em 15, 5 e 1 minuto, respeitando leitor
de tela. Oferecer pedido de extensão sem interromper salvamento. Nunca encerrar
durante atualização do sistema; coordenação com inibidores systemd é obrigatória.

Se contagem multi-sessão ou suspensão não for confiável, mostrar “quota
indisponível” em vez de estimativa apresentada como exata.

## Fluxo 6 — contestação, retificação e revogação

- Contestação não altera automaticamente o sinal nem apaga evidência necessária.
- O usuário escolhe categoria e texto opcional; nenhum campo induz revelação de
  documento ou dado sensível.
- O responsável recebe notificação e pode corrigir configuração local.
- Contestação do método/sinal segue canal definido pela ADR/fornecedor.
- Toda decisão mostra resultado e possibilidade de nova revisão.
- Revogar compartilhamento informa previamente quais consumidores perderão o
  sinal e qual comportamento seguro será aplicado.

## Desativação e recuperação

Desativar exige:

1. autenticação do responsável;
2. resumo das salvaguardas removidas;
3. escolha separada sobre excluir dados opcionais;
4. transação com rollback;
5. verificação pós-aplicação.

Não oferecer botão “desativar tudo” ao lado de ajuste cotidiano. Em falha, o
backend mantém a política anterior e a interface não declara sucesso.

## Acessibilidade

- WCAG 2.2 AA como referência; navegação completa por teclado;
- ordem de foco acompanha hierarquia visual;
- estado nunca depende apenas de cor/ícone;
- mudanças assíncronas anunciadas por região acessível sem repetição excessiva;
- alvos de toque adequados e suporte a texto ampliado/reflow;
- gráficos possuem tabela/resumo textual equivalente;
- cronômetros não piscam e avisos podem ser relidos;
- linguagem curta, concreta e revisada para diferentes idades;
- autenticação não quebra leitor de tela nem devolve foco ao início.

## Inventário mínimo de textos

Cada mensagem possui ID estável, sem concatenar frases:

- títulos/descrições dos estados globais;
- explicação de cada controle e limitação;
- autenticação, confirmação, sucesso, falha e rollback;
- pedidos, contestação, retificação e revogação;
- avisos de tempo;
- dados, finalidade, retenção e consumidores;
- códigos de indisponibilidade dos adaptadores.

Catálogos completos nos três idiomas são requisito de merge da #109.

## Pesquisa e validação antes da implementação

- revisão com especialista jurídico, privacidade e segurança;
- revisão de acessibilidade com Orca, teclado, escala 200% e contraste;
- sessões separadas com responsáveis e adolescentes, sem coletar dados além do
  consentido para a pesquisa;
- teste de compreensão: distinguir declarado/verificado, filtro completo/camada
  complementar e pedido/autorização;
- threat modeling de coerção, responsável abusivo, dispositivo compartilhado e
  administrador comprometido;
- protótipo deve usar backend simulado, nunca dados reais de menores.

## Critérios de aceite para #108

- fluxos acima revisados por segurança, privacidade e acessibilidade;
- método etário permanece slot bloqueado até #106/#111;
- perfil inicial protetivo e ausência de dark patterns demonstrados;
- visão do usuário supervisionado e limitações explícitas presentes;
- inventário i18n criado na implementação #109;
- nenhum elemento do protótipo é confundido com enforcement funcional.

# ADR 0002: protocolo JSON Lines e plano versionado

- Estado: aceita
- Data: 2026-08-08
- Issue: #35

## Contexto

O frontend sem privilégio precisa enviar uma escolha confirmada ao serviço
root e receber progresso, falhas e avisos. O serviço não pode confiar que o
estado dos discos permaneceu igual entre a tela de resumo e a autorização.

## Decisão

Usar stdin/stdout com uma mensagem JSON por linha. O frontend envia um
`ExecutionRequest` contendo:

- `choice`: intenção original do usuário;
- `plan`: `InstallPlan` imutável exibido na confirmação;
- `config`: locale, teclado, fuso, hostname e conta.

`InstallPlan.schema_version` é obrigatório e começa em `1`. O serviço rejeita
uma versão desconhecida antes de executar qualquer operação. Depois, refaz a
descoberta, reconstrói o plano a partir de `choice` e exige igualdade exata
com o plano confirmado.

O serviço responde com `Started`, `Step`, `Warning`, `Failed` ou `Completed`.
Uma linha `ExecutionControl::Cancel` pode pedir cancelamento entre operações.
Senhas ficam no payload em memória somente pelo tempo da execução, nunca em
argv, eventos ou arquivos temporários.

## Compatibilidade

Qualquer alteração estrutural ou semântica que possa ser interpretada de modo
diferente por um serviço antigo incrementa `INSTALL_PLAN_SCHEMA_VERSION`. Não
há coerção silenciosa nem migração automática de planos destrutivos. Frontend
e serviço são entregues no mesmo RPM e devem concordar sobre a versão.

## Consequências

- o protocolo é inspecionável, reproduzível e fácil de testar sem D-Bus;
- o plano exibido é exatamente o plano autorizado;
- stdin/stdout não oferece persistência ou retomada automática;
- o frontend recebe cada evento durante a execução e mantém a resposta final
  completa como fallback; o cancelamento na interface ainda precisa ser
  conectado na #38;
- D-Bus fica rejeitado para a Beta 2; poderá substituir o transporte sem
  alterar os tipos de domínio se requisitos futuros justificarem.

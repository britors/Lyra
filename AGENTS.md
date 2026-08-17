# Princípios do projeto Lyra

## Estabilidade em primeiro lugar

O Lyra é uma distribuição Linux LTS, estável, sólida e confiável, voltada à
experiência de “instalar e ficar tranquilo”. O usuário não deve precisar
administrar constantemente o sistema para mantê-lo funcional, seguro e
previsível. Preserve esse objetivo em toda decisão de arquitetura,
implementação, empacotamento, atualização e release.

Prefira componentes maduros, atualizações conservadoras, compatibilidade de
longo prazo, padrões seguros, recuperação confiável e baixa necessidade de
manutenção. Evite trocar tecnologias ou ampliar funcionalidades apenas por
novidade quando isso aumentar a superfície de falhas, a carga operacional ou
o risco de regressão sem um benefício claro para o usuário.

## Lapidação sobre o openSUSE

O openSUSE é a fundação técnica do Lyra, não um detalhe a ser ocultado ou
substituído. Reaproveite seus componentes, empacotamento, mecanismos de
segurança, atualização e recuperação sempre que forem adequados. Evite criar
alternativas exclusivas do Lyra para problemas que a base já resolve bem.

O diferencial do Lyra é lapidar essa base como um produto coerente: integrar
hardware, drivers, energia, aplicativos, atualizações e rollback; identificar
combinações problemáticas; transformar incidentes reais em políticas e testes;
e remover a necessidade de intervenção técnica recorrente. A experiência de
uso confiável de distribuições como o TUXEDO OS é uma referência de qualidade
de integração, sem implicar copiar sua arquitetura ou ampliar o escopo do Lyra.

Ao avaliar uma mudança, prefira primeiro corrigir a integração, a configuração,
o empacotamento ou a qualificação da base existente. Introduza tecnologia nova
somente quando houver uma lacuna demonstrável e benefício suficiente para
compensar o custo de manutenção e o risco de regressão.

## Limite de escopo do ciclo de release

Ideias, mudanças de produto e novas funcionalidades podem ser propostas e
avaliadas durante as versões Alpha, sempre respeitando a prioridade de
estabilidade. A Beta 1 inicia o congelamento funcional do ciclo.

Da Beta 1 em diante — incluindo todas as Betas, RCs e a versão final — aceite
somente refinamentos, estabilização e correções de bugs identificados. Não
introduza funcionalidades novas, mudanças amplas de arquitetura ou expansão
de escopo nessa fase. Registre propostas desse tipo para o próximo ciclo.

Se uma solicitação feita após o início da Beta 1 contrariar esse congelamento,
alerte o mantenedor antes de agir. Uma exceção só deve avançar quando for
necessária para corrigir um problema bloqueante e vier acompanhada de análise
de risco, testes de regressão e plano de reversão.

Antes de executar uma solicitação que possa reduzir a estabilidade, a
confiabilidade, a segurança, a compatibilidade, a capacidade de recuperação
ou a previsibilidade do sistema:

1. alerte explicitamente o mantenedor sobre o risco e seu impacto provável;
2. proponha uma alternativa mais segura quando ela existir;
3. identifique as validações, o plano de reversão e as evidências necessárias;
4. não faça a mudança arriscada silenciosamente.

Não trate toda mudança como perigosa por padrão. O alerta deve ser concreto,
proporcional ao risco e fundamentado no comportamento técnico esperado.

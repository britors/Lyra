# Lyra OS (Ubuntu Base)

Projeto de distribuição Linux customizada baseada em Ubuntu.

## Requisitos
- [Cubic](https://launchpad.net/cubic) instalado.
- ISO oficial do Ubuntu (Desktop).

## Workflow de Customização
1. Abra o Cubic.
2. Selecione a ISO base do Ubuntu.
3. No ambiente `chroot` do Cubic, aplique as customizações (instalação de pacotes, temas, scripts).
4. Gere a nova ISO.

## Estrutura do Repositório
- `branding/`: Assets, wallpapers, temas.
- `scripts/`: Scripts de pós-instalação ou automação dentro do Cubic.
- `docs/`: Documentação de design e decisões.

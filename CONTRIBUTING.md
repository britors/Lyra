# Contribuindo com o Lyra OS

Obrigado pelo interesse em contribuir. Este documento descreve como o
projeto é organizado e o fluxo esperado para propor mudanças.

## Antes de programar: a especificação

Funcionalidades novas ou mudanças estruturais neste projeto costumam
nascer como um documento `PROMPT-<nome>.md` na raiz do repositório
(ex.: `PROMPT-LYRA-ISO-SETUP-HOST.md`,
`PROMPT-CALAMARES-MIGRACAO-WINDOWS.md`). Esses arquivos descrevem o
comportamento esperado, os critérios de validação e o escopo antes de
qualquer código ser escrito. Se sua contribuição é maior que uma
correção pontual:

1. Verifique se já existe um `PROMPT-*.md` cobrindo a área que você
   quer mexer — ele é a fonte de verdade para decisões de design.
2. Para mudanças de escopo (não apenas de implementação), proponha o
   ajuste na especificação primeiro, numa issue ou PR separado.
3. Implemente de acordo com o que a especificação descreve, e cite a
   seção relevante (`§N`) em comentários onde a motivação não for óbvia.

Correções de bug, ajustes de packaging e pequenas melhorias não
precisam de uma especificação nova — só um PR direto já serve.

## Estrutura do repositório

Ver a seção "Estrutura do repositório" do [`README.md`](README.md)
para o mapa completo (`lyra-iso/`, `branding/`, `lyra-branding/`,
`calamares-lyra-winmigrate/`).

## Testando suas mudanças

- **Módulos Python** (ex.: `calamares-lyra-winmigrate/`): cada módulo
  com lógica não-trivial separa código puro (testável sem
  `libcalamares`) do glue code que fala com o Calamares. Rode os testes
  com `python3 tests/<arquivo>.test.py -v` a partir do diretório do
  pacote, ou deixe o `makepkg` rodar tudo via `check()`.
- **Pacotes Pacman** (`PKGBUILD`): rode `makepkg` localmente antes de
  abrir o PR. Se o pacote tiver `check()`, ele precisa passar.
- **ISO completa**: `cd lyra-iso && ./scripts/quickstart.sh` prepara o
  host, gera a imagem e sobe a VM QEMU num único comando — é o caminho
  recomendado se você nunca buildou o ISO nesta máquina. Se já tem o
  host preparado, `sudo ./build.sh` seguido de `./scripts/run-qemu.sh`
  fazem só a parte de gerar e testar. Veja a seção "Build rápido" do
  README para detalhes.

Mudanças em `airootfs/`, `packages.x86_64`, ou nos módulos do Calamares
merecem pelo menos um boot em VM antes do PR — não são coisas fáceis
de revisar só lendo o diff.

## Estilo de commit

O histórico usa mensagens curtas no padrão `tipo: descrição` (`feat:`,
`fix:`, `chore:`, `docs:`), no imperativo, focadas no *porquê* quando
não for óbvio. Veja `git log --oneline` para exemplos recentes.

## Enviando um PR

1. Fork do repositório.
2. Branch descritiva para a sua mudança.
3. PR com descrição clara do que mudou e, se aplicável, como testar.
4. Sem `--no-verify` em hooks e sem force-push em branches compartilhadas.

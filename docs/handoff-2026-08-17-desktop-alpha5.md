# Ponto de retomada — Desktop Alpha 5

Atualizado em **17/08/2026**, antes da formatação da estação de desenvolvimento.
Este documento é o contexto canônico para retomar o trabalho após instalar o
Lyra OS Desktop Alpha 5 e o Codex. Ele não contém senhas, tokens nem chaves
privadas.

## Instrução rápida para a próxima sessão

Depois de clonar o repositório, peça ao Codex:

> Leia `AGENTS.md` e `docs/handoff-2026-08-17-desktop-alpha5.md` por completo.
> Confira o estado local e remoto antes de alterar qualquer coisa e continue a
> partir das pendências registradas no handoff.

O repositório canônico é `git@github.com:britors/Lyra.git`, branch `main`. O
último commit confirmado e publicado antes da formatação é:

```text
d5ea06471211fc2559d3f1c79a71c38d9a324fec
Prepare Desktop Alpha 5 release identity
```

A árvore estava limpa e `HEAD` era igual a `origin/main` quando este handoff
foi preparado. Este próprio documento será acrescentado em um commit posterior;
na retomada, use o `HEAD` mais novo que o contém.

## Estado executivo

A ISO **Lyra OS Desktop 2026.08 Alpha 5 “Odisseia”** foi construída e testada
em VM pelo mantenedor. A avaliação do mantenedor foi que a versão está muito
fluida, estável e sem erros observados na instalação. A instalação, o primeiro
boot e o uso básico foram aprovados informalmente para publicação como Alpha.

O bundle local de publicação foi gerado e validado, mas o upload ao SourceForge
**não foi concluído por esta sessão**: o SSH exigiu autenticação interativa e o
ambiente do agente não conseguiu abrir `ksshaskpass`. A tentativa falhou antes
de transferir arquivos; não houve publicação parcial conhecida. A primeira
tarefa na nova instalação é verificar o diretório público e, se necessário,
publicar o bundle novamente.

Destino público planejado:

```text
https://sourceforge.net/projects/lyra/files/releases/1.0/desktop/alpha5/
```

## Identidade e artefato construído

- versão: `2026.08-alpha5`;
- codinome: `Odisseia`;
- arquitetura: `x86_64`;
- nome: `lyra-os.x86_64-2026.08-alpha5.iso`;
- commit de origem gravado: `d5ea06471211fc2559d3f1c79a71c38d9a324fec`;
- SHA-256 validado:
  `72fa2b0481e6053d5291faf5166dae44ef7d9a071ba79451a689d0fca00963f2`;
- tamanho observado: aproximadamente 2,1 GB;
- assinatura destacada da ISO: intencionalmente ausente nas Alphas, conforme
  ADR 0005; será obrigatória a partir da Beta 1. Pacotes e repositórios RPM
  continuam obrigatoriamente assinados.

Antes da formatação, os artefatos existiam somente na estação em:

```text
kiwi/.kiwi/test-1001/iso/
```

Esse diretório é gerado e não deve ser presumido recuperável depois da
formatação. Se o upload não estiver completo, reconstrua a ISO a partir do
commit limpo em vez de confiar em uma cópia sem procedência.

Bundle esperado:

```text
README.md
lyra-os.x86_64-2026.08-alpha5.cdx.json
lyra-os.x86_64-2026.08-alpha5.iso
lyra-os.x86_64-2026.08-alpha5.iso.manifest.json
lyra-os.x86_64-2026.08-alpha5.iso.sha256
lyra-os.x86_64-2026.08-alpha5.packages
lyra-os.x86_64-2026.08-alpha5.report
lyra-os.x86_64-2026.08-alpha5.spdx.json
lyra-os.x86_64-2026.08-alpha5.verified
```

## O que foi implementado para a Alpha 5

### Confiabilidade do instalador

O commit `472cd8f` implementou as correções relacionadas às issues #90, #91 e
#92:

- política de assinatura alinhada ao estágio: SHA-256 sem assinatura GPG da ISO
  antes da Beta 1, sem relaxar assinaturas de repositório/RPM;
- teste destrutivo em loop device estritamente fail-closed;
- instalador não informa sucesso se desmontagem ou limpeza final falhar;
- testes de regressão cobrem as transições e falhas relevantes.

O teste real relatado pelo mantenedor concluiu instalação e reinicialização sem
erros. `sudo` com a senha do usuário funcionou.

### Git, Fish e nvm-fish

Na primeira candidata o Fish informou falta do Git. O pacote `git` foi tornado
explícito na imagem Desktop. Na VM, o mantenedor instalou Git para continuar os
testes e confirmou o funcionamento. A correção definitiva está no manifesto da
Alpha 5 e é acompanhada pela issue #104.

### LinuxToys

LinuxToys 6.6.2 foi empacotado como RPM do Lyra e incluído somente no profile
Desktop. Os mecanismos próprios de atualização (`curl | bash` e `git pull`)
foram desabilitados para que atualizações ocorram exclusivamente por RPM/Zypper.
O pacote foi construído no OBS, promovido e testado com sucesso. Issue #95.

### Lyra Welcome

Foi criado um aplicativo Rust/Tauri simples de boas-vindas:

- interface em `en-US`, `pt-BR` e `es-ES`;
- detecta automaticamente o idioma do sistema, sem seletor e sem scrollbar;
- botão “Começar a usar o Lyra” fecha a janela por comando nativo Rust;
- não usa rede nem privilégios;
- possui ícone próprio;
- abre somente no primeiro login de cada usuário;
- ignora o usuário live `liveuser`;
- registra conclusão em `$XDG_STATE_HOME/lyra/welcome-completed` somente após
  saída limpa, evitando perder a tela após falha;
- distribuído por RPM `lyra-welcome` e XDG autostart.

O mantenedor validou visualmente a tela e aprovou o desenho. O commit principal
é `472cd8f`; o polimento final do pacote está em `9fdc54c`.

### Thunderbird e localização

O commit `4fe37b9` adicionou ao Desktop:

- `MozillaThunderbird`;
- `MozillaThunderbird-translations-common`.

O pacote oficial do openSUSE Leap 16 fornece `pt-BR` e `es-ES`; `en-US` já vem
no aplicativo. A política acompanha o idioma selecionado na instalação. Não foi
incluído `MozillaThunderbird-translations-other` para evitar peso sem benefício
para os três idiomas suportados.

### Identidade da release

O commit `d5ea064` mudou a identidade completa de Alpha 4 para Alpha 5:

- `release.toml`;
- metadados e volume KIWI;
- identificação no instalador e no sistema instalado;
- notas em `docs/releases/lyra-os-desktop-2026.08-alpha5.md`;
- `scripts/build-desktop-alpha5.sh`;
- `scripts/upload-desktop-alpha5-sourceforge.sh`;
- testes da convenção de release.

Na validação final, `./scripts/image-build.py validate` passou e a suíte tinha
**212 testes aprovados**. `git diff --check` e a sintaxe dos scripts também
passaram.

## OBS em 17/08/2026

O projeto `home:rodrigosbrito:lyra`, repositório `openSUSE_Leap_16.0`, estava
com estado `published`. Entre os pacotes com build `succeeded` estavam:

- `linuxtoys`;
- `lyra-installer`;
- `lyra-welcome`;
- `nvm-fish`;
- `aladfar`, `beam`, `chord`, `postgres-draco`, `sheliak` e `sulafat`;
- subpacotes de tema `lyra-os-icons` e `lyra-os-theme`.

`lyra-theme` aparecia `excluded` porque seus subpacotes são os artefatos úteis.
O projeto ainda contém os pacotes legados extras `calco` e `prosa`. Eles não
foram removidos, pois essa limpeza é uma mudança separada e não era necessária
para construir a ISO. Não apagá-los automaticamente na retomada.

LinuxToys foi promovido pela request OBS `#1371609` e Lyra Welcome pela
`#1371612`; ambas haviam sido aceitas. Thunderbird vem do repositório oficial
do openSUSE, não do OBS do Lyra.

## Testes manuais já relatados

O mantenedor relatou na VM:

- sessão live iniciou sem erro;
- instalador concluiu sem erro;
- sistema instalado iniciou após reboot;
- `sudo` funcionou;
- desempenho e fluidez excelentes;
- LinuxToys funcionou;
- Lyra Welcome foi aprovado visualmente;
- Alpha 5 foi considerada a melhor versão do Lyra testada até então.

A candidata anterior ainda mostrava label Alpha 4; isso motivou e foi corrigido
pelo commit `d5ea064`. Na retomada, confirme que a ISO publicada/reconstruída
mostra **Alpha 5** no boot, instalador e sistema instalado.

Esses relatos são evidência manual informal, não os JSONs estruturados do gate
formal. Para uma Alpha experimental, o mantenedor decidiu que boot, instalação,
primeiro boot, uso básico, checksum e ausência de P0/P1 observados são
suficientes para publicação. Secure Boot, rollback completo e matriz física
continuam desejáveis durante o ciclo.

## Pendências imediatas, em ordem

1. Instalar a Alpha 5 na máquina física e preservar/baixar este repositório.
2. Configurar Git, autenticação GitHub (`gh auth login` e chave SSH, se usada) e
   autenticação do SourceForge/OBS. Nunca registrar segredos no repositório.
3. Clonar `git@github.com:britors/Lyra.git`, ler `AGENTS.md` e este handoff.
4. Verificar `git status`, `git log -1`, `git fetch` e `git pull --ff-only`.
5. Abrir o diretório público da Alpha 5 e conferir se há todos os nove arquivos
   do bundle. A tentativa feita pelo agente não enviou arquivos.
6. Se os artefatos não estiverem publicados, reconstruir com
   `./scripts/build-desktop-alpha5.sh` e publicar no terminal interativo com
   `./scripts/upload-desktop-alpha5-sourceforge.sh --verify-download`.
7. Confirmar que o download público tem o SHA-256 registrado acima.
8. Registrar/fechar as issues Alpha 5 já implementadas apenas depois de anexar
   os commits e os resultados de teste: #90, #91, #92, #95 e #104.
9. Triar #94 (NVIDIA/monitor externo) conforme hardware disponível; não afirmar
   que foi corrigida sem reprodução e evidência.
10. Resolver a inconsistência de `docs/release-gate.md`, cujo título e texto
    ainda dizem Desktop Alpha 3. Definir um gate proporcional para Alphas e o
    gate completo a partir da Beta 1, preservando a ADR 0005.
11. Retomar a arquitetura do Lyra Upgrade na issue #81. A implementação foi
    deliberadamente movida para Alpha 6: epic #84 e issues #82, #83, #86, #88 e
    #103. Não inserir o updater às pressas na Alpha 5 já validada.

## Issues abertas relevantes

### Marcadas Alpha 5

- #104 — incluir Git para Fish/nvm-fish: implementada, falta atualizar/fechar;
- #95 — pré-instalar LinuxToys: implementada e publicada no OBS, falta fechar;
- #94 — monitor externo NVIDIA não acorda após DPMS/suspensão: pendente;
- #92 — falha de desmontagem não pode virar sucesso: implementada;
- #91 — teste destrutivo fail-closed: implementada;
- #90 — assinatura por estágio: implementada;
- #81 — contratos do Lyra Upgrade: ainda aberta; reavaliar escopo/label porque
  a implementação está planejada para Alpha 6;
- #84 e #73 — epics que atravessam versões.

### Próximo foco planejado

A Alpha 6 concentra o Lyra Upgrade:

- #103 — aplicativo em Rust;
- #86 — core, preflight e máquina de estados;
- #83 — serviço privilegiado e atualização da mesma release;
- #82 — upgrade entre releases;
- #88 — interface Tauri e i18n.

A arquitetura deve aproveitar Zypper, Snapper e rollback do openSUSE. O projeto
considerou usar um JSON publicado junto aos arquivos do SourceForge para
informar a versão atual e versões antigas/suportadas. A ideia é promissora, mas
o documento deve ser autenticado, validado por schema, servido com política de
fallback segura e nunca ser a única fonte de verdade para executar comandos
privilegiados. Especificar isso em #81 antes de programar.

## Comandos de retomada e verificação

Preparação básica, ajustando o caminho se necessário:

```bash
git clone git@github.com:britors/Lyra.git ~/Git/Lyra
cd ~/Git/Lyra
git status --short
git log -1 --oneline
./scripts/release.py check
./scripts/image-build.py validate
python3 -m unittest discover -s tests
```

Consultar OBS:

```bash
osc results home:rodrigosbrito:lyra
osc results home:rodrigosbrito:vega
osc results home:rodrigosbrito:fina
```

Construir e preparar a Alpha 5 novamente:

```bash
./scripts/build-desktop-alpha5.sh
```

Testar em VM descartável — o script já recria disco e NVRAM, portanto não
existe flag `--fresh`:

```bash
./kiwi/test/build-and-run-vm.sh --published-installer
```

Reusar uma ISO local existente:

```bash
./kiwi/test/build-and-run-vm.sh --skip-build
```

Testar Secure Boot separadamente:

```bash
./kiwi/test/build-and-run-vm.sh --skip-build --secure-boot
```

Validar sem enviar e depois publicar:

```bash
./scripts/upload-desktop-alpha5-sourceforge.sh --check-only
./scripts/upload-desktop-alpha5-sourceforge.sh --verify-download
```

O segundo comando deve ser executado em terminal interativo, pois SSH pode pedir
senha ou passphrase. Não envie credenciais ao Codex e não as grave em arquivo.

## Cuidados importantes

- O Lyra prioriza estabilidade, previsibilidade, recuperação e integração com
  openSUSE; leia sempre `AGENTS.md` antes de decidir arquitetura.
- A Beta 1 inicia feature freeze. Depois dela, apenas estabilização e correções,
  salvo exceção bloqueante com risco, regressão e rollback documentados.
- Não sobrescrever silenciosamente uma ISO já publicada mantendo checksum ou
  nome antigo. Se houver correção, retirar/ocultar a candidata afetada e criar
  uma nova candidata rastreável.
- Não apagar pacotes OBS legados nem alterar projetos de release sem inspeção e
  autorização explícita.
- Não guardar senha do SourceForge, token GitHub, chave GPG ou chave SSH neste
  documento ou no repositório.
- Antes de qualquer commit novo, verificar árvore suja e preservar mudanças do
  mantenedor.

## Commits centrais desta etapa

```text
472cd8f Prepare Alpha 5 desktop integration
9fdc54c Polish Lyra Welcome packaging
4fe37b9 Add localized Thunderbird to desktop image
d5ea064 Prepare Desktop Alpha 5 release identity
```

Esses quatro commits contêm o núcleo do trabalho relatado neste handoff.

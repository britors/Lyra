# PROMPT-LYRA-FISH-FISHER.md

## Contexto

O Lyra OS (base openSUSE Leap 16, edição GNOME) adota o **fish como shell
padrão** da conta de usuário do desktop, **com Fisher e o conjunto de
plugins de produtividade já ativos numa instalação nova** — sem nenhum
passo manual do usuário. Não é um pacote opcional para avançados: é
parte da experiência de terminal do sistema.

A metade "fish é o shell padrão" já está implementada:

- `installer/src/service/operations/deploy.rs:525` define
  `DEFAULT_DESKTOP_SHELL = "/usr/bin/fish"`, usado no `useradd` da conta
  criada pelo instalador;
- `kiwi/config.xml:115` cria o `liveuser` da ISO com
  `shell="/usr/bin/fish"`;
- `kiwi/config.xml:444` instala o `fish` na imagem, e `:448` instala o
  `nvm-fish` empacotado (integração nativa versionada do nvm para fish,
  já que o `nvm.sh` POSIX não suporta fish);
- `kiwi/root/usr/share/fish/vendor_conf.d/lyra-defaults.fish` e
  `vendor_functions.d/fish_prompt.fish` já entregam greeting e prompt
  vendor.

Bash continua sendo o shell de `root` (`kiwi/config.xml:104`) e da
edição Server (`scripts/server-install.sh:704`) — nenhuma das duas coisas
é alterada aqui.

O que falta, e é o objeto deste prompt, é a metade "com Fisher e com os
plugins": empacotar essa camada e fazê-la chegar pronta na imagem.

## Objetivo

Empacotar (RPM no OBS `home:rodrigosbrito:lyra`) e embarcar na imagem um
pacote que:

1. Entrega Fisher e o conjunto de plugins validados por Rodrigo **já
   instalados** na conta criada por uma instalação nova, funcionando no
   primeiro terminal, **inclusive numa máquina instalada sem rede**.
2. Torna o `hydro` o prompt padrão do Lyra OS, sem atropelar um prompt
   que o usuário tenha customizado por conta própria.
3. Entrega os 9 itens da lista canônica, incluindo o `nvm.fish` do
   Fisher, que passa a ter precedência sobre o RPM `nvm-fish` já
   embarcado na imagem.
4. É idempotente, reparável e reversível: reexecutar não duplica nada,
   uma conta quebrada se recupera com um comando, e nada disso trava o
   shell se falhar.

## Decisões de arquitetura (pré-resolvidas)

- **Nome do pacote:** `lyra-fish-productivity`
- **Shell padrão:** fish, já configurado pelo instalador e pela ISO.
  O pacote **não** mexe em `/etc/passwd` e não roda `chsh` — o shell já
  vem certo. Um usuário que prefira outro shell continua livre para rodar
  `chsh -s /bin/bash`; nesse caso o pacote fica inerte.
- **Pré-instalação na imagem: sim.** `<package
  name="lyra-fish-productivity"/>` entra no set padrão do perfil desktop
  em `kiwi/config.xml`, junto de `fish` e `nvm-fish`. O pacote continua
  publicado no OBS (necessário para atualização e para instalação
  avulsa), mas o caminho principal deixa de ser
  `zypper install` — é a imagem.
- **Seed em tempo de build, não em tempo de primeiro login.** Como o pack
  agora é padrão, depender de um download do GitHub no primeiro terminal
  é inaceitável: uma instalação feita offline ficaria sem plugins, e toda
  instalação nova bateria no GitHub. O `kiwi/config.sh` roda o setup uma
  vez durante o build da imagem e materializa o resultado em
  `/etc/skel/.config/fish/` (functions, completions, conf.d e
  `fish_plugins`), de onde o `useradd -m` do instalador copia para cada
  conta nova. O `liveuser` da ISO já tem home criada pelo KIWI, então o
  `config.sh` precisa copiar o seed para `/home/liveuser` explicitamente
  e corrigir a posse.
- **Rede: exigida só no build, nunca no uso.** Uma instalação nova, um
  primeiro boot e um primeiro terminal funcionam 100% offline. A rede só
  reaparece nos caminhos de reparo/atualização descritos abaixo.
- **Escopo de instalação:** por usuário. Os arquivos gerados vivem em
  `~/.config/fish/` (semeados via `/etc/skel`), então cada conta tem sua
  própria cópia e pode customizar ou remover à vontade sem afetar as
  outras. Os arquivos do pacote em si (functions do Lyra, lista canônica
  de plugins) ficam read-only em `/usr/share/lyra-fish-productivity/` e
  `/usr/share/fish/vendor_functions.d/`, atualizáveis por RPM.
- **Fisher não tem pacote RPM oficial:** o bootstrap baixa a function
  `fisher.fish` do GitHub. Isso acontece no build; o resultado é
  versionado dentro do RPM/imagem, não rebaixado a cada boot.
- **Dependências no `.spec`:** `fish` (>= 3.4, já atendido pelo Leap 16 e
  já na imagem), `fzf`, `curl`. `git` já é dependência do sistema base
  (tornado explícito no Alpha 5 justamente por causa do fish/nvm-fish).

## Plugins incluídos (validados individualmente por Rodrigo)

Lista canônica em `/usr/share/lyra-fish-productivity/fish_plugins`; o
setup resolve a partir dela e grava o resultado efetivo no
`~/.config/fish/fish_plugins` (manifesto do próprio Fisher):

```
jorgebucaran/fisher
PatrickF1/fzf.fish
jethrokuan/z
jorgebucaran/autopair.fish
franciscolourenco/done
jorgebucaran/hydro
edc/bass
jhillyerd/plugin-git
jorgebucaran/nvm.fish
```

### `hydro` é o prompt padrão do Lyra OS

Decisão fechada: numa instalação nova, o prompt visível é o do `hydro`
(path abreviado, branch e estado do git resolvidos de forma assíncrona,
duração do último comando). Consequências a implementar:

- O `fish_prompt.fish` que o hydro instala em
  `~/.config/fish/functions/` tem precedência natural sobre o vendor —
  não é preciso deletar nada para o hydro aparecer.
- `kiwi/root/usr/share/fish/vendor_functions.d/fish_prompt.fish`
  **permanece na imagem, rebaixado a fallback**. Ele continua servindo
  contas que não recebem o seed (root, edição Server) e evita que uma
  conta fique com prompt quebrado se o usuário remover o pack ou os
  plugins do Fisher — o custo de manter é zero e o de remover é uma
  regressão silenciosa nesses casos.
- A detecção de prompt customizado (`__lyra_fish_foreign_prompt`) olha
  **apenas** `~/.config/fish/`, nunca os diretórios vendor. Isso hoje é
  acidental e passa a ser comportamento exigido: o prompt vendor do Lyra
  **não** conta como conflito (senão o hydro nunca ativaria), enquanto um
  Starship/oh-my-posh/tide/`fish_prompt` do próprio usuário conta e
  preserva a customização dele, deixando o hydro instalado e inativo.
  Prenda isso com teste.
- Cores do hydro: definir os `$hydro_color_*` em
  `vendor_conf.d/lyra-defaults.fish`, alinhados à paleta do Lyra, para
  que o prompt padrão seja branding e não default upstream.

### `nvm.fish` vem do Fisher; o RPM `nvm-fish` vira fallback

O set instalado é a lista completa, os 9 itens — `nvm.fish` incluído.
O Lyra também empacota essa integração como RPM `nvm-fish`
(`kiwi/config.xml:448`), e as duas cópias convivem sem conflito por
precedência de path, não por exclusão:

- o RPM instala `nvm.fish`, `_nvm_*.fish` e `conf.d/nvm.fish` em
  `/usr/share/fish/vendor_{functions,conf,completions}.d/`;
- o Fisher instala os mesmos nomes em `~/.config/fish/`, que vem **antes**
  dos diretórios vendor no `$fish_function_path`;
- fish resolve function por primeira ocorrência no path e deduplica
  snippets de `conf.d` por basename, então a cópia do Fisher é a que
  carrega, uma única vez, sem duplo source.

O RPM permanece na imagem pelo mesmo motivo do `fish_prompt` vendor:
serve as contas que não recebem o seed (root, edição Server) e mantém o
`nvm` funcional se o usuário remover os plugins do Fisher. Não há flag
de exclusão — a lista canônica é instalada inteira, sempre.

## Estrutura de arquivos do pacote

```
lyra-fish-productivity/
├── lyra-fish-productivity.spec          # spec RPM (OBS)
├── conf.d/
│   └── lyra-fish-bootstrap.fish         # reparo/atualização, não 1º uso
├── fish_plugins                         # lista canônica (read-only)
├── functions/
│   ├── fish_setup_lyra_plugins.fish     # setup: build-time e manual
│   ├── lyra_fish_status.fish            # diagnóstico
│   ├── __lyra_fish_foreign_prompt.fish  # detecta prompt do usuário
│   ├── __lyra_fish_system_provides.fish # só diagnóstico: detecta o par
│   │                                    # vendor sombreado pelo Fisher
│   ├── __lyra_fish_state_dir.fish       # resolve ~/.local/state/…
│   ├── __lyra_fish_record_failure.fish  # marca falha p/ backoff
│   ├── __lyra_fish_msg.fish             # mensagens localizadas
│   ├── __lyra_fish_locale.fish          # pt/es/en
│   └── __lyra_fish_version.fish         # versão do pacote (@VERSION@)
└── docs/
    └── README.md                        # o que vem pronto, diagnóstico,
                                         # como customizar e como sair
```

### Comportamento do `fish_setup_lyra_plugins`

A mesma função serve os três caminhos: seed no build da imagem, reparo
manual e atualização pós-RPM.

1. Verifica se `curl` e `git` estão disponíveis; aborta com mensagem
   clara se não.
2. Verifica conectividade com **os dois** hosts envolvidos:
   `raw.githubusercontent.com` (de onde vem o `fisher.fish`) e
   `api.github.com` (de onde o `fisher install` puxa os tarballs).
   Testar só o primeiro deixa passar uma rede que alcança um e não o
   outro, e a instalação quebra no meio. Se falhar, informa, registra a
   falha e sai sem erro fatal.
   No build da imagem essa falha é fatal para o build (ver checklist) —
   uma ISO sem os plugins não pode ser publicada silenciosamente.
3. Instala Fisher se ainda não presente (`functions --query fisher`).
4. Lê a lista canônica e instala o set completo, sem exclusões.
5. Roda `fisher install` com o set em **uma única invocação**
   (não um por vez), para evitar múltiplas re-resoluções de dependências.
6. Preserva prompt do usuário: se `__lyra_fish_foreign_prompt` detectar
   customização em `~/.config/fish/`, faz backup de
   `functions/fish_prompt.fish` antes do `fisher install` e restaura
   depois — hydro fica instalado e inativo. Numa conta nova (semeada) não
   há customização, então o hydro ativa normalmente.
7. Grava o marcador `~/.local/state/lyra-fish-productivity/installed`
   com versão do pacote, data e set efetivamente instalado. O seed em
   `/etc/skel` inclui esse marcador, para que o primeiro terminal de uma
   conta nova não tente nada.

### Comportamento do `conf.d/lyra-fish-bootstrap.fish`

Com o seed em `/etc/skel`, este snippet deixa de ser o caminho de
primeiro uso e passa a cobrir só os casos onde o seed não se aplica:

- conta criada antes do pack entrar na imagem;
- conta cujo `~/.config/fish/` foi limpo ou veio de backup/migração;
- atualização do RPM que muda a lista canônica — compara a versão do
  marcador com a versão do pacote e reexecuta o setup quando diferem.

Em todos eles o comportamento é o mesmo: roda em background lógico,
falha em silêncio útil (mensagem, nunca travamento), e respeita o
backoff do `__lyra_fish_record_failure` para não bater no GitHub a cada
terminal aberto de uma máquina offline.

### Comportamento do `lyra_fish_status`

Diagnóstico (`lyra_fish_status`) que lista, por plugin da lista canônica,
se está instalado e ativo, sinalizando explicitamente os estados
esperados: "sombreando a cópia vendor" (nvm.fish sobre o RPM
`nvm-fish`) e "instalado mas inativo" (hydro numa conta com prompt
customizado). Mostra também a
origem da configuração da conta (seed de imagem vs. bootstrap em
runtime) e a versão registrada no marcador — suporte/self-service sem
precisar abrir issue.

## Integração com GNOME Software / Vega

- Por vir na imagem, o pacote não precisa ser descoberto no GNOME
  Software; ele aparece lá de qualquer forma (repositório OBS habilitado
  por padrão) e é por lá que chegam as atualizações.
- Fora de escopo para o v1: módulo dedicado no Vega para gerenciar os
  plugins por toggle. Avaliar depois; não bloqueia esta entrega.

## Checklist de validação

- [ ] Build da imagem falha ruidosamente se o seed do Fisher/plugins não
      completar — nunca publicar ISO com o pack pela metade
- [ ] ISO nova instalada **com a rede desconectada**: primeiro terminal
      da conta criada já tem fisher, os 8 plugins e o prompt do hydro,
      sem nenhuma tentativa de download
- [ ] `fisher list` na conta nova imprime exatamente os 9 itens da lista
      canônica, `nvm.fish` incluído
- [ ] `nvm` na conta nova resolve para `~/.config/fish/functions/nvm.fish`
      (`functions --details nvm`), não para a cópia vendor, e
      `nvm install`/`nvm use` funcionam
- [ ] Sessão live (`liveuser`) tem o mesmo estado da conta instalada —
      seed copiado e posse corrigida
- [ ] Abrir vários terminais não dispara reinstalação nem I/O de rede
      (idempotência confirmada via `lyra_fish_status`)
- [ ] `fish_setup_lyra_plugins` rodado manualmente uma segunda vez não
      duplica nem quebra plugins já instalados
- [ ] Conta com Starship pré-configurado (upgrade de máquina existente):
      o setup não sobrescreve o prompt, hydro fica instalado e inativo, e
      `lyra_fish_status` reporta esse estado
- [ ] Conta antiga sem seed, offline: o bootstrap imprime erro claro, não
      trava o terminal, e o terminal seguinte continua utilizável
- [ ] `root` e a edição Server continuam em bash, e o `fish_prompt`
      vendor continua servindo quem cai nele
- [ ] Remover os plugins do Fisher devolve a conta às cópias vendor sem
      quebra: `fisher remove hydro` volta ao prompt vendor, `fisher
      remove nvm.fish` volta ao `nvm` do RPM
- [ ] `zypper remove lyra-fish-productivity` não remove a config já
      gerada em `~/.config/fish/` (preservação de dados do usuário)

## Fora de escopo

- Alterar o shell padrão de qualquer conta — o desktop já usa fish por
  decisão fechada; root e Server continuam em bash.
- Módulo de UI no Vega para gerenciar plugins fish (avaliar em versão
  futura).
- Abreviações (`abbr`) customizadas para cargo/go/npm/git — tratado como
  prompt separado, se e quando solicitado.
- Suporte a KDE/outros DEs neste prompt — segue a mesma disponibilidade
  geral de pacotes OBS do Lyra, sem tratamento especial.

# Lyra Fish Productivity Pack

Fisher e o conjunto de plugins fish do Lyra OS. Numa instalação nova não
há nada a fazer: o fish já é o shell padrão da conta e os plugins já vêm
instalados e ativos no primeiro terminal, inclusive numa máquina que
nunca viu a internet — o conjunto é preparado durante o build da imagem e
copiado para cada conta nova via `/etc/skel`.

## O que vem instalado

| Plugin | Para que serve |
|---|---|
| `jorgebucaran/fisher` | gerenciador de plugins |
| `PatrickF1/fzf.fish` | busca interativa (histórico, arquivos, git) |
| `jethrokuan/z` | salta para diretórios usados com frequência |
| `jorgebucaran/autopair.fish` | fecha aspas, parênteses e colchetes |
| `franciscolourenco/done` | notifica quando um comando longo termina |
| `jorgebucaran/hydro` | o prompt do Lyra OS |
| `edc/bass` | roda scripts bash de dentro do fish |
| `jhillyerd/plugin-git` | abreviações e helpers de git |
| `jorgebucaran/nvm.fish` | gerencia versões do Node |

## Conferir o estado da conta

```fish
lyra_fish_status
```

Lista plugin a plugin o que está instalado e ativo, e mostra quando e a
partir de qual versão esta conta foi preparada. Dois estados são normais
e não indicam problema:

- **`nvm.fish` — ativo, à frente da cópia do sistema.** O Lyra também
  empacota essa integração como RPM `nvm-fish`, nos diretórios vendor.
  A cópia do Fisher, em `~/.config/fish`, tem precedência; a do sistema
  fica como reserva para contas sem este pacote.
- **`hydro` — instalado, inativo.** Acontece quando a conta já tinha um
  prompt próprio (Starship, oh-my-posh, tide ou um `fish_prompt`
  escrito à mão). A preparação nunca sobrescreve prompt customizado.

## Reinstalar ou reparar

```fish
fish_setup_lyra_plugins
```

Reexecutável quantas vezes for preciso: não duplica nem quebra o que já
está instalado. Útil numa conta criada antes deste pacote existir, num
`~/.config/fish` que foi limpo, ou depois de uma falha de rede.

Sem internet o comando informa o erro e sai — o terminal continua
utilizável, e a tentativa automática recua por 24 horas para não bater no
GitHub a cada terminal aberto.

## Customizar

Tudo o que a preparação gera vive em `~/.config/fish/` e é seu. Para
trocar o prompt, por exemplo:

```fish
fisher remove jorgebucaran/hydro
```

A conta volta ao prompt vendor do Lyra, sem quebra. O mesmo vale para
qualquer outro plugin do conjunto. Para adicionar plugins fora da lista,
use o Fisher normalmente — a preparação só reinstala a lista canônica
quando a versão do pacote muda, e nunca remove o que você adicionou.

Cores do prompt e demais padrões interativos do sistema ficam em
`/usr/share/fish/vendor_conf.d/lyra-defaults.fish`; qualquer coisa
definida em `~/.config/fish/config.fish` tem precedência sobre eles.

## Sair do fish

O pacote não mexe em `/etc/passwd`. Para usar outro shell:

```fish
chsh -s /bin/bash
```

A configuração em `~/.config/fish/` continua intacta, inclusive se o
pacote for removido com `zypper remove lyra-fish-productivity` — nenhuma
das duas ações apaga dados da sua conta.

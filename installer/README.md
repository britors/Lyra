# Lyra Installer

Frontend nativo do instalador do Lyra OS, escrito em Rust com Tauri 2. A
interface é HTML/CSS/JavaScript estático servido pelo WebKitGTK do sistema,
com o núcleo de domínio e a futura ponte privilegiada em Rust. Neste primeiro
estágio ele implementa a navegação do assistente, os padrões de produto
(`pt_BR.UTF-8` e `lyra-os`) e a validação dos dados da conta sem executar
nenhuma operação destrutiva.

```bash
cd installer
cargo test
cargo tauri dev
```

O comando `cargo tauri dev` abre o layout visual em Tauri. O build não depende
de fontes ou recursos remotos: as telas e todos os estilos ficam em `ui/`.

O executável gráfico sempre roda como o usuário da sessão live. Operações de
disco são expostas pelo `service/` (`lyra-installer-service`), um binário
separado, lançado via `pkexec` só durante a execução do plano — nunca a
interface inteira. A interface não deve chamar ferramentas de disco por meio
de uma shell nem ser iniciada inteira com `pkexec`.

`lyra-installer-core::storage` já cobre a descoberta de discos, RAID (mdadm)
e LVM (`pvs`/`vgs`/`lvs`) e a montagem de um plano de instalação declarativo
em dry-run — só leitura, sem executar nada destrutivo. `cargo test` cobre
esse módulo com fixtures (disco vazio, ocupado, ESP existente, espaço
insuficiente, RAID saudável/degradado, RAID+LVM combinados). O comando
Tauri `discover_storage` e o novo `plan_install` (recebe o `GuidedChoice`
inteiro vindo da UI — não mais só um `disk_path` — e chama
`PlanBuilder::build`; continua dry-run, sem I/O) alimentam a tela de
armazenamento do assistente (`ui/index.html`/`ui/app.js`): um alternador
"Disco único"/"Array RAID novo" no topo troca o modo da lista de discos
entre seleção única (radio) e múltipla (checkbox); no modo RAID, um
seletor de nível (0/1/5/6/10, com o mínimo de discos de cada um) decide
o `RaidLevel` enviado. Os dois modos mostram os discos elegíveis com o
motivo quando um está bloqueado (mídia live, membro de RAID/LVM, já
particionado), o resumo destrutivo e os avisos do plano, e só liberam
"Continuar" quando o plano é válido — inclusive o erro real do
`PlanBuilder` quando menos discos que o mínimo do nível são marcados,
sem duplicar essa regra em JS.

Um toggle "Usar LVM" (independente do modo disco/RAID, já que
`storage::plan` valida RAID+LVM combinados) troca `volume_layer` de
`Direct` para `NewVolumeGroup{name: "vg-lyra", logical_volumes}`. O
editor de logical volumes começa com uma linha fixa (`root` em `/`,
`FillRemaining`, não removível — `PlanBuilder` exige uma LV montada em
`/`) e permite adicionar/remover outras, cada uma com nome, ponto de
montagem e tamanho fixo (GiB) ou "preencher o restante". Isso volta
atrás de uma decisão de escopo tomada mais cedo na mesma sessão ("só
RAID novo, sem editor de LVM, para manter o assistente guiado" — ver
`docs/installer-architecture.md`); pedido explícito depois. `ExistingRaid`
(reaproveitar array já existente) continua sem tela.

`window.__TAURI__` precisou ser
habilitado (`withGlobalTauri: true` em `tauri.conf.json`) porque este
frontend é HTML/JS estático sem bundler, então não há import de
`@tauri-apps/api`; comandos definidos no próprio binário (via
`invoke_handler`) não passam pelo sistema de ACL do Tauri 2, só os das
plugins, então nenhuma entrada de capability foi necessária para os dois
comandos.

`service/` já traz o arcabouço de execução segura do plano
(`lyra-installer-core::service`): protocolo em JSON lines, revalidação do
plano contra o estado atual do disco antes de qualquer escrita, allow-list
de binários (sem shell), cancelamento e desmontagem em ordem reversa sempre
ao final (sucesso ou falha). O comando Tauri `execute_plan` lança
`pkexec service/lyra-installer-service`, autorizado pela action
`io.lyra.Installer.execute-plan`
(`kiwi/root/usr/share/polkit-1/actions/io.lyra.Installer.policy` +
`kiwi/root/etc/polkit-1/rules.d/01-lyra-installer-service.rules`).

`lyra-installer-core::service::operations` já implementa o particionamento
real (GPT, ESP, Btrfs, os 21 subvolumes de
`storage::plan::default_subvolumes`, mount, `/etc/fstab` com UUID real) para
o caso "disco inteiro, layout direto" — RAID e LVM como alvo ainda devolvem
um erro explícito de "não implementado", não silêncio. `cargo test` cobre a
lógica pura (ordem das operações, argv exato, nunca formatar uma ESP
reaproveitada); o que `cargo test` **não** cobre é execução real em disco,
porque este ambiente de desenvolvimento não tem privilégio para
`losetup`/`sgdisk`/`mkfs`. `service/test-loop-device.sh` existe pronto para
isso — precisa rodar com `sudo`, ainda não foi executado, é o próximo passo
antes de confiar nesse caminho contra hardware de verdade.

Primeira rodada da auditoria de paridade do #44: comparei `deploy.rs` contra
os binários/scripts do Calamares realmente instalados num build já feito
(`kiwi/.kiwi/test-1000/build/build/image-root`), não contra suposição — dava
pra rodar `strings` nos módulos compilados (`.so`) e ler os `.py` direto.
Achei e fechei duas lacunas reais: fuso horário (o módulo `locale` real
grava `/etc/localtime` e `/etc/timezone` no alvo, confirmado via `strings`
em `libcalamares_viewmodule_locale.so`; `deploy.rs` não tinha nenhuma
operação equivalente, nem `InstallConfig` tinha campo pra isso) e o
fallback RTC→ISA do `hwclock` (o `main.py` real tenta `hwclock --systohc
--utc` e, se falhar, tenta de novo com `--directisa`, sem nunca abortar a
instalação mesmo se as duas falharem; `SetHardwareClock` só tentava uma vez
e propagava erro). `InstallConfig` ganhou um campo `timezone` (validado
contra as 4 opções do `<select id="timezone">` da tela "Região", mesmo
padrão do allowlist de locale) e `WriteTimezone` roda entre `WriteKeyboard`
e `WriteLocale` — a ordem real do `settings.conf` é `locale` (fuso) →
`keyboard` → `localecfg` (nosso `WriteLocale`), então o reordenamento
também corrige uma inversão que já existia ali.

Segunda rodada da auditoria: conferi `users`/`packages`/`installcleanup`/
`mount`/`partition`/`grubcfg`/`uefibootloader` contra os `.conf` reais em
`kiwi/root/etc/calamares/modules/`. `installcleanup` bateu exatamente (os
dois `const` do Rust — `LIVE_ONLY_ARTIFACTS` + `LYRA_INSTALLER_ARTIFACTS` —
somados reconstroem os 10 caminhos do `rm -f` real, um a um). `GRUB_DISTRIBUTOR`
não é bug: já vem copiado do squashfs live pelo `ExtractRootfs` (o
`grubcfg` real só mescla os poucos campos do seu `defaults:`, que não
inclui `GRUB_DISTRIBUTOR`, sobre o arquivo já existente no target).

Achei e corrigi mais duas lacunas reais, uma delas séria:

- **`efivarfs` nunca montado no chroot.** `mount.conf`'s `extraMounts`
  monta `efivarfs` em `/sys/firmware/efi/efivars`, `tmpfs` em `/run` e faz
  bind de `/run/udev` — `uefibootloader.conf`'s próprio comentário confirma
  por quê: "grub/shim need it to create the UEFI NVRAM entry from inside
  the target system". O Rust só fazia bind de `/proc`/`/sys`/`/dev`; um
  `mount --bind /sys` simples **não** propaga o `efivarfs` já montado
  dentro de `/sys` no host (precisaria de `--rbind`), então `efibootmgr`
  (chamado internamente pelo `shim-install` do `InstallShimAndGrub`) não
  tinha onde escrever a variável UEFI dentro do chroot — a instalação
  terminava "com sucesso" mas sem entrada NVRAM real, só o fallback
  removível do shim. Adicionei `MountVirtualFs` (monta `tmpfs`/`efivarfs`,
  dispositivo == tipo, igual ao `mount.conf` real) e o bind de
  `/run/udev`, todos antes do `RunDracut`.
- **`useradd -G` só tinha `wheel`.** `users.conf` real define
  `defaultGroups: users, lp, video, network, storage, wheel, audio` — o
  `CreateUser` do Rust só passava `wheel`, deixando a conta sem acesso
  padrão a vídeo/áudio/mídia removível/impressão. Corrigido para o mesmo
  conjunto de 7 grupos.

Terceira rodada: portei o último item que tinha ficado deliberadamente de
fora — `packages.conf`'s `try_remove: [calamares,
calamares-branding-upstream]`. Lido direto do `main.py` real: o backend
`zypp` roda, por pacote, `zypper --non-interactive remove <pkg>` dentro do
chroot do target, e `operation_try_remove` remove **um pacote de cada
vez**, engolindo a falha de cada um individualmente — é por isso que
`try_remove` existe (uma mudança de nome do pacote de branding não pode
derrubar uma instalação que, fora isso, terminou certa). `RemoveCalamaresPackages`
porta isso literalmente, inclusive a tolerância por pacote. Precisou
adicionar `zypper` à `ALLOWED_BINARIES` (única finalidade: remover
exatamente esses dois pacotes, nunca com nome vindo de plano/usuário).

Quarta rodada: fechei o `/etc/default/keyboard` e conferi o Netplan de
verdade em vez de deixar como "achado menor". `WriteKeyboard` agora
escreve `/etc/default/keyboard` (`XKBMODEL="pc105"` — valor literal do
próprio módulo real, sem seletor de modelo no wizard — mais
`XKBLAYOUT`/`XKBVARIANT`/`BACKSPACE="guess"`), condicionado a
`/etc/default` já existir, igual ao `WriteLocale`. Não é código morto:
`/usr/bin/setupcon` está presente na imagem e lê exatamente esse
arquivo. Já o Netplan em `networkcfg` **não foi portado, de propósito,
verificado**: `/etc/netplan` não existe em lugar nenhum da imagem
construída, nem o pacote `netplan` — o bloco correspondente do módulo
real nunca executaria aqui (`if os.path.exists(source_netplan) and
os.path.exists(target_netplan)`), então portar seria código morto sem
nenhum ganho, não uma lacuna real.

Quinta rodada: reconferi `fstab`, `unpackfs` e `snapshotcfg` (grounding
anterior existia, mas não tinha sido re-auditado nesta série de
sessões). `fstab` sem achado novo — é uma reimplementação própria do
Rust a partir de `storage::plan`, as opções de mount já batiam via
`mount.conf`. `unpackfs`: descobri que o módulo real **não** usa um
`unsquashfs -f -d` simples — ele monta o squashfs e copia arquivo por
arquivo em Python, com uma correção explícita (`repair_root_permissions`)
pra um bug conhecido do squashfs que deixa a raiz extraída com permissão
`777`. Tentei reproduzir localmente com um squashfs de teste feito na
hora e não consegui (`unsquashfs -f -d` preservou 755 corretamente) —
então pode ser um gatilho específico de versão/flags que não bati nesse
teste. Portei a correção mesmo assim (`repair_root_permissions` em
`deploy.rs`): é barata, só age exatamente em `777`, e replica um
workaround real do upstream, não uma suposição. `snapshotcfg`: reli
`lyra-configure-btrfs-rollback` (o script bash que `PrepareBtrfsRollback`/
`MountSnapshotsSubvolume` portam) linha por linha contra a lógica awk do
Rust — confere exatamente, só duas diferenças cosméticas sem efeito
real (tab vs espaço nas linhas reescritas do fstab; um fallback de campo
vazio vs `"0"` que nunca dispara porque o próprio `WriteFstab` do Rust
sempre escreve as 6 colunas).

**Parcialmente resolvido**: a tela de resumo agora monta um `InstallConfig`
real a partir do que foi preenchido (idioma, fuso, hostname, nome
completo, usuário, senha) e chama o novo comando Tauri
`validate_install_config` — que só roda `InstallConfig::validate()` de
verdade, sem I/O — mostrando qualquer erro (ex.: fuso horário fora das 4
opções, layout de teclado fora da lista). Isso é o que faltava pro
`<select id="timezone">` deixar de ser só decorativo.

`InstallConfig` agora também tem `keyboard_layout`, alimentado pelo
seletor da tela 4 (42 opções). Investigação real (não suposição) revelou
que o mecanismo antigo do `WriteKeyboard` (escrever
`/etc/X11/xorg.conf.d/00-keyboard.conf`) nunca teve efeito nenhum na
sessão real: GNOME 48+ aqui roda em Wayland por padrão, e Wayland não
consulta config de Xorg — não existe processo Xorg rodando pra ler aquele
arquivo. O mecanismo certo, confirmado contra a documentação oficial do
dconf (wiki.gnome.org/Projects/dconf/SystemAdministrators), é um default
sistêmico via `/etc/dconf/profile/user` + `/etc/dconf/db/local.d/` +
`dconf update` no chroot, escrevendo `org.gnome.desktop.input-sources`.
`WriteKeyboard` foi reescrito pra isso; `vconsole.conf` continua sendo
escrito também (efeito só no TTY via Ctrl+Alt+F3, sem relação com a
sessão gráfica).

O mapeamento de cada um dos 42 ids do seletor pro layout/variante XKB real
(`KEYBOARD_LAYOUTS` em `src/lib.rs`) foi conferido contra
`/usr/share/X11/xkb/rules/base.lst` desta própria máquina, não suposto —
o que revelou dois ids do próprio seletor que estavam errados, corrigidos
nesta sessão: `uk` (Ucraniano) não existe como layout XKB, o código real é
`ua` (`ui/app.js` corrigido); `la` (rotulado "Latina" no wizard) é na
verdade o código XKB do **Laociano** (`la` = Lao), um idioma completamente
diferente — como não existe layout XKB de "Latim clássico" em lugar
nenhum do upstream, mapeado pra `us` em vez do idioma errado. `ch-de` e
`br-abnt2` também não têm variante com esses nomes — a checagem confirmou
que os layouts *base* `ch` e `br`, sem variante nenhuma, já são
alemão-suíço e ABNT2 respectivamente.

**Limitação que não é nova, é pré-existente e compartilhada com o
Calamares**: idiomas que precisam de método de entrada de verdade
(japonês, coreano, chinês/pinyin, tailandês, árabe, persa, hebraico)
só recebem o layout XKB básico — sem `ibus`, não tem conversão
fonética→ideograma nem composição real. Confirmado via `strings` no
`.so` real do módulo `keyboard` do Calamares: zero referências a
`gsettings`/`dconf`/`ibus`/`org.gnome` — o Calamares também nunca
configurou método de entrada nenhum, em nenhum dos dois caminhos. E
`kiwi/config.xml` não instala nenhum pacote `ibus-*` hoje — isso é uma
decisão de conteúdo da imagem, fora do escopo do `installer/`.

**O que continua faltando, de propósito**: nada chama `execute_plan`
ainda — o botão "Instalar" segue desabilitado ("Backend em
desenvolvimento"), porque isso dispararia o serviço privilegiado fazendo
partição/formatação de verdade, e isso só faz sentido depois de
`service/test-loop-device.sh` rodar validado (ver acima) e da matriz de
testes do #44.

`operations::deploy` implanta o rootfs no target já particionado: extrai o
squashfs da sessão live, machine-id, fuso horário, teclado, locale
(mapeamento de teclado fixo por locale por enquanto — sem tela própria),
hostname, cria o usuário (senha só via stdin do `chpasswd`, nunca em argv),
`sudoers.d`, initramfs via `chroot` (achei e corrigi um bug real: o
`dracut.conf` efetivo do Calamares hoje grava o initramfs num nome errado —
ver `docs/installer-architecture.md`), remove `liveuser` e artefatos da
sessão live, ajusta prioridade dos repositórios Lyra, copia perfis de rede
e sincroniza o relógio em UTC. Por último (depois da limpeza do
`liveuser`, de propósito): `/etc/default/grub` do target, `grub2-mkconfig`,
`shim-install` (Secure Boot nativo do Leap — o fallback EFI e a entrada
NVRAM já saem de graça dessa ferramenta, não precisei reimplementar),
`btrfs subvolume set-default` + fstab sem `subvol=` (porta do
`lyra-configure-btrfs-rollback` real), `snapper create-config`, fstab com
`/.snapshots`, `dracut --force --fstab` de novo, primeiro snapshot
somente-leitura do Snapper, e `grub2-mkconfig` mais uma vez pro submenu de
rollback aparecer. Achei e corrigi outro bug real de quebra: o `grubcfg`
duplicava `"splash"` em `GRUB_CMDLINE_LINUX_DEFAULT` (detecção automática
de plymouth somada ao valor já configurado) — ver
`docs/installer-architecture.md`. `operations::build(request)` junta
particionamento + implantação (incluindo bootloader/Snapper) + `sync`
final. Fora de escopo por enquanto: remover os pacotes do Calamares do
target (fica para a auditoria de paridade da #44); rollback e Secure Boot
continuam sem confirmação de boot real — `kiwi/test/build-and-run-vm.sh
--secure-boot`/`--boot-disk --secure-boot` já existem prontos pra isso.

O Calamares continua sendo o instalador ativo da imagem de desenvolvimento
enquanto o serviço Tauri/Rust não implementa e valida todo o pipeline descrito em
[`../docs/installer-architecture.md`](../docs/installer-architecture.md).

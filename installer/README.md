# Lyra Installer

Frontend nativo do instalador do Lyra OS, escrito em Rust com Tauri 2. A
interface é HTML/CSS/JavaScript estático servido pelo WebKitGTK do sistema,
com o núcleo de domínio e o serviço privilegiado em Rust. Ele implementa a
navegação do assistente, descoberta e planejamento de armazenamento, os
padrões de produto (`pt_BR.UTF-8` e `lyra-os`) e a configuração do target. A
execução destrutiva é iniciada somente na tela final, depois da validação do
plano/configuração e de uma confirmação explícita do destino que será apagado.

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
Tauri `discover_storage` e `plan_install` alimentam a tela de armazenamento
do assistente (`ui/index.html`/`ui/app.js`). Na Alpha 3, a interface oferece
somente `RawTarget::Disk` + `VolumeLayer::Direct`, o único caminho que o
serviço privilegiado executa de ponta a ponta. RAID, LVM, RAID+LVM e o modo
customizado continuam modelados e testados no núcleo, mas não aparecem na
interface enquanto a execução correspondente não existir no backend. A lista
mostra os discos elegíveis, o motivo quando um está bloqueado, o resumo
destrutivo e os avisos do plano, e só libera “Continuar” quando o plano é
válido.

Todo `InstallPlan` carrega `schema_version`. A versão atual é `3`; o serviço
rejeita versões desconhecidas antes de executar qualquer operação e reconstrói
o plano contra um snapshot novo para detectar estado obsoleto. Os contratos e
as regras de evolução estão em `docs/adr/0002-json-lines-privileged-protocol.md`
e `docs/installer-state-machine.md`.

A mesma etapa oferece três cards de memória virtual. `Zram` é o padrão e
grava uma configuração zstd no sistema instalado; `Disk` reserva uma partição
swap de 8 GiB, executa `mkswap` e inclui seu UUID no `fstab`; `None` não cria
swap e remove a configuração do `zram-generator`. A escolha faz parte de
`GuidedChoice` e do plano revalidado, não é apenas estado visual do frontend.

`window.__TAURI__` precisou ser
habilitado (`withGlobalTauri: true` em `tauri.conf.json`) porque este
frontend é HTML/JS estático sem bundler, então não há import de
`@tauri-apps/api`. Comandos definidos no próprio binário (via
`invoke_handler`) não passam pelo sistema de ACL do Tauri 2, mas a API de
eventos passa: `src-tauri/capabilities/main.json` libera somente `listen` e
`unlisten` para a janela principal, necessários para acompanhar ao vivo os
eventos de progresso emitidos por `execute_plan`.

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

Uma auditoria do sistema-alvo encontrou e fechou duas lacunas reais: gravação
do fuso horário em `/etc/localtime` e `/etc/timezone`, que ainda não existia
em `deploy.rs`, e o fallback RTC→ISA do `hwclock`. O serviço tenta
`hwclock --systohc --utc` e, se falhar, tenta de novo com `--directisa`, sem
abortar a instalação mesmo se as duas falharem; antes,
`SetHardwareClock` só tentava uma vez e propagava erro. `InstallConfig`
ganhou um campo `timezone` (validado
contra as 4 opções do `<select id="timezone">` da tela "Região", mesmo
padrão do allowlist de locale) e `WriteTimezone` roda antes de
`WriteKeyboard` e `WriteLocale`.

A auditoria de usuários, pacotes, limpeza, mounts, particionamento e boot
confirmou que `LIVE_ONLY_ARTIFACTS` e `LYRA_INSTALLER_ARTIFACTS` cobrem todos
os caminhos transitórios. `GRUB_DISTRIBUTOR` já vem copiado do squashfs live
pelo `ExtractRootfs` e é preservado quando o instalador mescla os campos
gerenciados.

Achei e corrigi mais duas lacunas reais, uma delas séria:

- **`efivarfs` nunca montado no chroot.** GRUB e shim precisam de `efivarfs`
  em `/sys/firmware/efi/efivars`, `tmpfs` em `/run` e do bind de `/run/udev`
  para criar a entrada UEFI NVRAM. O Rust só fazia bind de
  `/proc`/`/sys`/`/dev`; um
  `mount --bind /sys` simples **não** propaga o `efivarfs` já montado
  dentro de `/sys` no host (precisaria de `--rbind`), então `efibootmgr`
  (chamado internamente pelo `shim-install` do `InstallShimAndGrub`) não
  tinha onde escrever a variável UEFI dentro do chroot — a instalação
  terminava "com sucesso" mas sem entrada NVRAM real, só o fallback
  removível do shim. Adicionei `MountVirtualFs` (monta `tmpfs`/`efivarfs`,
  dispositivo == tipo) e o bind de `/run/udev`, todos antes do `RunDracut`.
- **`useradd -G` só tinha `wheel`.** A política desktop exige os grupos
  `users, lp, video, network, storage, wheel, audio`; o
  `CreateUser` do Rust só passava `wheel`, deixando a conta sem acesso
  padrão a vídeo/áudio/mídia removível/impressão. Corrigido para o mesmo
  conjunto de 7 grupos.

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

**Limitação conhecida**: idiomas que precisam de método de entrada de verdade
(japonês, coreano, chinês/pinyin, tailandês, árabe, persa, hebraico)
só recebem o layout XKB básico — sem `ibus`, não tem conversão
fonética→ideograma nem composição real. `kiwi/config.xml` não instala nenhum
pacote `ibus-*` hoje — isso é uma
decisão de conteúdo da imagem, fora do escopo do `installer/`.

O botão da tela final chama `execute_plan` com o mesmo `GuidedChoice`,
`InstallPlan` e `InstallConfig` exibidos no resumo. Ele só é liberado depois
da validação Rust e de o usuário marcar a confirmação destrutiva. Enquanto o
`pkexec` e o serviço rodam, a navegação fica bloqueada; ao final, os eventos
estruturados indicam sucesso, avisos ou a etapa da falha. Uma falha emitida
depois do início da execução é terminal e exige reabrir o instalador, porque
o plano confirmado pode ter sido parcialmente aplicado. O streaming de cada
evento durante uma operação longa continua pendente; nesta versão a tela
mostra um estado indeterminado e recebe a lista completa ao término.

Cada tentativa recria `~/lyra-installer-trace.log` como o usuário da sessão
live, com permissão `0600`. O arquivo registra versão e origem do build, plano
confirmado, configuração com a senha removida, cada evento do serviço, stderr
e status final do processo. Ele é atualizado enquanto os eventos chegam, por
isso permanece útil quando a instalação é interrompida e pode ser anexado
diretamente a um relatório de erro.

Quando o serviço termina com sucesso e emite o evento terminal `Completed`, o
frontend também grava atomicamente `~/lyra-installer-result.json`, com permissão
`0600`. Esse arquivo contém somente versão/origem e eventos estruturados, sem a
configuração da conta ou senha, e é a evidência `installer` consumida pelo gate
da Beta 2. Uma falha ao gravá-lo fica anotada no trace sem transformar uma
instalação já concluída em falha falsa.

`operations::deploy` implanta o rootfs no target já particionado: extrai o
squashfs da sessão live, machine-id, fuso horário, teclado, locale
(mapeamento de teclado fixo por locale por enquanto — sem tela própria),
hostname, cria o usuário (senha só via stdin do `chpasswd`, nunca em argv),
`sudoers.d`, initramfs via `chroot`, remove `liveuser` e artefatos da
sessão live, ajusta prioridade dos repositórios Lyra, copia perfis de rede
e sincroniza o relógio em UTC. Por último (depois da limpeza do
`liveuser`, de propósito): `/etc/default/grub` do target, `grub2-mkconfig`,
`shim-install` (Secure Boot nativo do Leap — o fallback EFI e a entrada
NVRAM já saem de graça dessa ferramenta, não precisei reimplementar),
`btrfs subvolume set-default` + fstab sem `subvol=` (porta do
`lyra-configure-btrfs-rollback` real), `snapper create-config`, fstab com
`/.snapshots`, `dracut --force --fstab` de novo, primeiro snapshot
somente-leitura do Snapper, e `grub2-mkconfig` mais uma vez pro submenu de
rollback aparecer. Antes da primeira snapshot, o RPM live-only
`lyra-installer` é removido também do banco RPM do target; isso impede que uma
atualização ou rollback restaure o serviço privilegiado e sua regra polkit.
Achei e corrigi outro bug real de quebra: o `grubcfg`
duplicava `"splash"` em `GRUB_CMDLINE_LINUX_DEFAULT` (detecção automática
de plymouth somada ao valor já configurado) — ver
`docs/installer-architecture.md`. `operations::build(request)` junta
particionamento + implantação (incluindo bootloader/Snapper) + `sync`
final. Rollback e Secure Boot continuam sem confirmação de boot real —
`kiwi/test/build-and-run-vm.sh --secure-boot` já prepara esse teste; depois da
instalação, o primeiro boot do disco deve ser feito reiniciando o guest na
mesma execução.

O Lyra Installer é o único instalador ativo da imagem Beta 2. A ISO permanece
pré-release enquanto o serviço e o pipeline descrito em
[`../docs/installer-architecture.md`](../docs/installer-architecture.md) não
forem validados de ponta a ponta.

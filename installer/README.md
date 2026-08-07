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
insuficiente, RAID saudável/degradado, RAID+LVM combinados). Os comandos
Tauri `discover_storage` e `plan_disk_install` (este último chama
`PlanBuilder::build` com a escolha "disco inteiro, layout direto" sobre o
snapshot já obtido pela UI — continua sendo dry-run, sem I/O) alimentam a
tela de armazenamento do assistente (`ui/index.html`/`ui/app.js`): lista os
discos elegíveis com o motivo quando um está bloqueado (mídia live, membro
de RAID/LVM, já particionado), mostra o resumo destrutivo e os avisos do
plano do disco selecionado, e só libera "Continuar" quando o plano é válido.
RAID e LVM como alvo continuam sem tela — só o caminho de disco único
inteiro está coberto pela UI por enquanto. `window.__TAURI__` precisou ser
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

Achados menores, não corrigidos: `networkcfg` real também copia config do
Netplan (provavelmente irrelevante pra Leap+GNOME, que só usa
NetworkManager); `keyboard` real também escreve `/etc/default/keyboard`,
que `WriteKeyboard` não escreve. Ainda não conferidos: `fstab` (módulo
genérico do Calamares — o Rust já é uma reimplementação própria a partir
de `storage::plan`, não uma porta do módulo, então "paridade" aqui é mais
sobre as opções de mount, já conferidas via `mount.conf`) e `unpackfs`/
`snapshotcfg` (grounding extenso já feito em sessões anteriores, não
re-verificado agora).

**Lacuna que continua aberta, sem código ainda**: nenhuma tela do
assistente monta um `InstallConfig` (nem chama `execute_plan`) — então o
`<select id="timezone">` da tela "Região" segue sem lugar pra onde fluir,
do mesmo jeito que o teclado da tela 4 também não alimenta o
`InstallConfig` ainda.

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

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
insuficiente, RAID saudável/degradado, RAID+LVM combinados). O comando Tauri
`discover_storage` expõe essa leitura para a UI; nenhuma tela nova para
escolher o destino de disco existe ainda.

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

`operations::deploy` implanta o rootfs no target já particionado: extrai o
squashfs da sessão live, machine-id, locale, teclado (mapeamento fixo por
locale por enquanto — `InstallConfig` ainda não tem campo próprio),
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

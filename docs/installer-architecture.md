# Arquitetura do Lyra Installer

As decisões aceitas estão em [`adr/`](adr/) e o fluxo normativo, incluindo
falhas e cancelamento, está em
[`installer-state-machine.md`](installer-state-machine.md).

## Decisão

O instalador final do Lyra OS será uma aplicação nativa em Rust + Tauri, com
interface HTML/CSS/JavaScript servida pelo WebKitGTK do sistema. A escolha
acompanha o desktop GNOME, permite uma primeira impressão visual mais rica e
responsiva e elimina a dependência visual e operacional do antigo instalador
Qt. Na Beta 2, o Lyra Installer é o único instalador presente na ISO; isso
torna seus testes end-to-end um bloqueador obrigatório do release.

## Limite de privilégios

```text
lyra-installer (usuário live, Tauri/WebKitGTK)
        │ configuração tipada + progresso
        ▼
lyra-installer-service (root, ativado/autorizado por polkit)
        │ chamadas sem shell e eventos auditáveis
        ▼
udisks/libblockdev + utilitários nativos do Leap + sistema-alvo
```

O frontend descobre opções, valida entradas, mostra o plano e exige confirmação
explícita. O serviço privilegiado volta a validar todos os valores e aceita
apenas operações previstas pela API. Senhas não entram em argumentos de
processos, logs ou arquivos temporários persistentes.

## Pipeline obrigatório

1. Detectar UEFI, energia, memória, conectividade e discos elegíveis.
2. Produzir um plano imutável e mostrar exatamente quais partições serão
   removidas ou preservadas.
3. Particionar em GPT e preparar ESP + Btrfs, com opção inicial de apagar o
   disco; particionamento manual fica bloqueado até ter cobertura própria.
4. Criar o layout de subvolumes compatível com o Leap, aplicando NoCOW onde
   exigido, e montar o sistema-alvo de forma privada.
5. Extrair `/run/overlay/live/LiveOS/squashfs.img` no destino, sem copiar os
   arquivos e privilégios exclusivos da sessão live.
6. Configurar locale, teclado, fuso, hostname, usuário administrativo via
   `wheel`/sudo e root bloqueado.
7. Gerar `fstab`, machine-id, initramfs e configuração do GRUB.
8. Instalar shim/GRUB pelo `shim-install` do Leap e validar o caminho de Secure
   Boot antes de declarar sucesso.
9. Configurar Snapper, criar o primeiro snapshot somente leitura e regenerar o
   menu de recuperação do GRUB.
10. Desmontar em ordem reversa, sincronizar os dados e emitir um relatório
    local de instalação sem dados secretos.

Operações de configuração devem convergir quando repetidas. Depois da primeira
escrita destrutiva não há retomada automática na Beta 2: uma falha encerra a
execução, libera recursos temporários e exige nova descoberta e confirmação.
Uma falha nunca pode resultar em mensagem de sucesso nem ocultar os eventos
relevantes para diagnóstico.

## Gate do instalador para publicar a Beta 2

- frontend acessível por teclado e leitor de tela, em pt-BR e inglês;
- backend com testes unitários de plano e testes de integração sobre loop
  devices/imagens descartáveis;
- instalação completa em VM UEFI com boot do destino;
- repetição do teste com Secure Boot e chaves Microsoft do OVMF;
- root bloqueado, sudo funcional e nenhum `liveuser`, autostart ou privilégio
  da sessão live presente no destino;
- Btrfs/Snapper e recuperação pelo GRUB comprovados;
- pacote RPM `lyra-installer` publicado no OBS do Lyra.

O KIWI já contém somente o pacote, autostart e regra de privilégio do Lyra
Installer. A ISO não pode ser publicada enquanto esse checklist não estiver
verde; não existe instalador alternativo ou fallback na Beta 2.

## Descoberta de armazenamento e plano (issue #39)

`lyra-installer-core::storage` já existe: `discovery` lê o estado atual de
discos/RAID/LVM sem privilégio (via `lsblk`, sysfs e `pvs`/`vgs`/`lvs`,
todos como leitura) e `plan` transforma isso mais a escolha do usuário em um
`InstallPlan` declarativo e puro — sem nenhuma chamada de sistema, o que é o
que garante o dry-run do passo 2 do pipeline acima. Os alvos suportados hoje
são disco inteiro, criação ou reaproveitamento de array RAID (mdadm) e
criação ou reaproveitamento de volume group LVM em cima do alvo bruto. A
execução real do plano (particionar, criar o array/VG, formatar) continua
sendo trabalho do `lyra-installer-service` (#37/#40), não deste módulo.

## Serviço privilegiado (issue #37)

`lyra-installer-core::service` e o binário `installer/service`
(`lyra-installer-service`) implementam o arcabouço de execução segura:
protocolo em JSON lines pelo stdin/stdout, revalidação do plano contra um
`StorageSnapshot` fresco antes de qualquer escrita (reaproveitando o
`PlanBuilder` de #39), allow-list de binários no `RealExecutor` (nunca
shell, nunca concatenação de string — escrita de arquivo como `/etc/fstab`
é `std::fs::write` direto do próprio processo, já root, não passa pela
allow-list de spawn de processo), cancelamento entre operações e
desfazimento em ordem reversa de tudo que rodou — **sempre**, sucesso ou
falha, não só em erro (é assim que o alvo fica desmontado ao final de uma
instalação bem-sucedida). `operation::PrivilegedOperation` deixou de ser um
enum vazio com #40 — ver a seção seguinte.

O `lyra-installer-service` é lançado via
`pkexec /usr/libexec/lyra-installer-service` só pelo comando Tauri
`execute_plan`, só durante a execução do plano — nunca a UI inteira. A
regra `01-lyra-installer-service.rules` libera a action
`io.lyra.Installer.execute-plan` só para `liveuser`, e essa action (declarada
em `io.lyra.Installer.policy`) está presa ao binário específico pela annotation
`org.freedesktop.policykit.exec.path`.

O RPM `lyra-installer` entrega interface, serviço, desktop entry, policy e
regra como um conjunto. `kiwi/config.xml` consome esse pacote e não contém um
segundo instalador.

## Particionamento e layout Btrfs (issue #40)

`lyra-installer-core::service::operations` traduz um `InstallPlan` em
operações reais para o caso "disco inteiro, layout direto": tabela GPT,
ESP (criada ou reaproveitada — nunca reformatada se reaproveitada),
`mkfs.btrfs`, os 21 subvolumes de `storage::plan::default_subvolumes`
criados e montados em `/run/lyra-installer/target` (mesma convenção
efêmera do `/run/overlay/live` do squashfs), `/etc/fstab` gerado com UUID
real via `blkid`, `sync` final. Alvos RAID/LVM (`NewRaid`, `ExistingRaid`,
`NewVolumeGroup`, `ExistingVolumeGroup`) devolvem
`OperationError::NotImplemented` explicitamente — ainda não têm tradução
implementada, isso não é um "faz nada" silencioso.

A ordem de montagem dos subvolumes importa por causa do desfazimento
sempre-executado descrito acima: montar do mais raso para o mais profundo
(`/` antes de `/home`, `/var/lib/machines` antes de `/var/lib/libvirt/images`)
é o que garante que desfazer em ordem reversa desmonte filhos antes dos
pais — montar um pai por cima de um filho já montado deixaria esse filho
com o mount preso.

**Não testado contra hardware/disco de verdade nesta sessão**: o ambiente
onde isso foi escrito não tem privilégio para `losetup`/`sgdisk`/`mkfs`.
`installer/service/test-loop-device.sh` existe pronto para validar isso com
uma imagem descartável via `sudo`, mas ainda precisa ser rodado (ex.: na VM
de teste do KIWI) antes desse caminho ser considerado confirmado na
prática, só na lógica pura coberta por `cargo test`.

## Implantação do rootfs e configuração do destino (issue #41)

`lyra-installer-core::service::operations::deploy` implanta o sistema no
target já particionado por #40: extrai `/run/overlay/live/LiveOS/squashfs.img`
(`unsquashfs -f`, preserva permissões/ACLs/xattrs), depois executa a sequência
Lyra auditada contra o comportamento do instalador anterior: machine-id,
locale, teclado,
hostname, criação do usuário (`useradd -R`/`chpasswd -R`, senha só via
stdin, nunca argv), `sudoers.d`, initramfs, remoção do `liveuser` e de
artefatos exclusivos da sessão live, redução de prioridade dos repositórios
Lyra, cópia dos perfis de rede salvos e relógio de hardware em UTC.
`operations::build(request)` é o ponto de entrada que junta particionamento
(#40) + implantação (#41) + `sync` final numa sequência só.

A maioria dos passos usa `--root`/`-R` (`useradd`, `userdel`, `chpasswd`,
`systemctl`) ou escreve arquivo direto (`std::fs::write`/`std::fs::symlink`)
sob o target, sem precisar de chroot — o processo já roda como root, então
gravar um arquivo não passa pela allow-list de spawn de processo, que
existe para *comandos*, não para E/S direta de um processo já confiável.
Só o `dracut` precisa de chroot de verdade (inspeciona `/lib/modules` do
próprio target): três operações `BindMount` (`/proc`, `/sys`, `/dev`) mais
`chroot <target> dracut -f`, desmontadas pelo mesmo desfazimento
sempre-executado de #40.

O serviço usa `dracut -f`, mantendo o nome de initramfs derivado do kernel, e
`InstallConfig` carrega explicitamente o layout de teclado selecionado. O
comportamento anterior permanece documentado em `docs/calamares-reference/`
somente como fonte histórica para a auditoria da migração.

Mesma limitação de #40: nada disso foi executado contra root/disco real
nesta sessão — só a lógica pura, com `FakeExecutor`/diretórios temporários
graváveis em `/tmp`, está coberta por `cargo test`.

## GRUB, shim (Secure Boot) e rollback via Snapper (issue #42)

Últimas operações de `deployment_operations()`, depois da limpeza do
`liveuser` e dos artefatos live — de propósito, porque o primeiro snapshot
do Snapper precisa nascer já sem isso. Reaproveita os bind mounts de
`/proc`/`/sys`/`/dev` que `RunDracut` (#41) já deixou de pé: como o
desfazimento do engine só roda no fim de toda a execução, o chroot
continua disponível para todas as operações abaixo sem montar nada de
novo. A implementação foi conferida contra `/usr/sbin/shim-install` (pacote
`shim`), o helper `lyra-configure-btrfs-rollback` inteiro e a configuração
histórica preservada em `docs/calamares-reference/`.

Sequência: grava `/etc/default/grub` do target (mesma lógica de merge do
`update_existing_config` real — descomenta/substitui chaves gerenciadas,
acrescenta as que faltam, nunca reescreve o arquivo inteiro) → `chroot
grub2-mkconfig` → `chroot shim-install --efi-directory=/boot/efi
--config-file=/boot/grub2/grub.cfg` → `btrfs subvolume set-default` no
target (sem chroot — é só um argumento de caminho) + remove `subvol=`/
`subvolid=` da linha raiz do fstab (porta direta do awk do
`prepare-root` real) → `chroot snapper create-config` → confere
`/.snapshots` e acrescenta a linha dele no fstab (porta do `mount-snapshots`
real) → `chroot dracut --force --fstab` (chamada separada da de #41,
pra reincorporar o fstab sem `subvol=`) → `chroot snapper create
--read-only ...` (primeiro snapshot) → `grub2-mkconfig` de novo (pro
submenu de rollback aparecer) → remove o helper bash e os próprios artefatos
do Lyra Installer do target.

**Achado real #2**: o `grubcfg` de verdade duplica `"splash"` —
`kernel_params: ["quiet","splash"]` do YAML mais a própria detecção
automática de `plymouth` do módulo (plymouth está instalado no target)
somam duas entradas, produzindo `GRUB_CMDLINE_LINUX_DEFAULT='quiet splash
splash'`. `lyra-installer-service` calcula o valor certo diretamente, sem
duplicar o parâmetro.

**`shim-install` real já resolve o fallback EFI sozinho**: sem
`--removable`, ele mesmo escreve `/boot/efi/EFI/boot/bootx64.efi` sempre
que esse caminho não existir ou pertencer a outra distro, e cria a entrada
NVRAM via `efibootmgr` internamente — não precisei reimplementar nada
disso; o serviço invoca diretamente a ferramenta suportada pelo Leap.

**O que continua sem confirmação, e por quê**: "Snapper lista/cria
snapshots após o primeiro boot", "rollback testado em VM" e "Secure Boot
ligado/desligado" exigem boot real, que este ambiente não tem como fazer.
A parte boa: **já existe tooling pronto pra isso** —
`kiwi/test/build-and-run-vm.sh --secure-boot` usa OVMF com chaves
Microsoft pré-inscritas; reiniciar o guest na mesma execução inicia o disco
já instalado preservando o NVRAM. `kiwi/README.md` já registra esse gap
("Validation status") — continua exatamente onde estava, não é novidade
desta sessão.

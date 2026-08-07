# Arquitetura do Lyra Installer

## Decisão

O instalador final do Lyra OS será uma aplicação nativa em Rust + Tauri, com
interface HTML/CSS/JavaScript servida pelo WebKitGTK do sistema. A escolha
acompanha o desktop GNOME, permite uma primeira impressão visual mais rica e
responsiva e elimina a dependência visual e operacional do Calamares/Qt no
produto final.

O Calamares permanece temporariamente na ISO de desenvolvimento. Removê-lo
antes de existir paridade no backend deixaria a imagem sem um caminho de
instalação validado.

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

Cada etapa deve ser idempotente ou registrar claramente seu ponto de retomada.
Uma falha nunca pode resultar em mensagem de sucesso nem ocultar os comandos e
logs relevantes para diagnóstico.

## Critério para substituir o Calamares na ISO

- frontend acessível por teclado e leitor de tela, em pt-BR e inglês;
- backend com testes unitários de plano e testes de integração sobre loop
  devices/imagens descartáveis;
- instalação completa em VM UEFI com boot do destino;
- repetição do teste com Secure Boot e chaves Microsoft do OVMF;
- root bloqueado, sudo funcional e nenhum `liveuser`, autostart ou privilégio
  da sessão live presente no destino;
- Btrfs/Snapper e recuperação pelo GRUB comprovados;
- pacote RPM `lyra-installer` publicado no OBS do Lyra.

Somente depois desse checklist o KIWI troca o pacote, o autostart, a regra de
polkit e remove `root/etc/calamares/`.

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

Diferente do Calamares (`Exec=pkexec /usr/bin/calamares`, a interface
inteira como root), o `lyra-installer-service` é lançado via
`pkexec /usr/libexec/lyra-installer-service` só pelo comando Tauri
`execute_plan`, só durante a execução do plano — nunca a UI inteira. A
autorização usa o mesmo padrão já comprovado para o Calamares
(`root/etc/polkit-1/rules.d/00-lyra-live-installer.rules`): uma nova regra
`01-lyra-installer-service.rules` libera a action `io.lyra.Installer.execute-plan`
só para `liveuser`, e essa action (declarada em
`root/usr/share/polkit-1/actions/io.lyra.Installer.policy`) está presa a
esse binário específico via a annotation
`org.freedesktop.policykit.exec.path`.

Como o pacote RPM do instalador ainda não existe (#53), nem `lyra-installer`
nem `lyra-installer-service` estão de fato instalados em nenhuma imagem
ainda — os arquivos de policy/regra ficam prontos, mas inertes, até lá.

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
(`unsquashfs -f`, preserva permissões/ACLs/xattrs), depois reproduz — lendo
o comportamento real do Calamares instalado (incluindo módulos sem
override no repo, como `machineid.conf`/`locale.conf`/`keyboard.conf`, cujo
`.conf` efetivo vem do `calamares-branding-upstream`) — a mesma sequência
que `settings.conf` roda depois do `fstab`: machine-id, locale, teclado,
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

**Achado real, não hipótese**: o `dracut.conf` efetivo hoje (sem override
Lyra, herdado do `calamares-branding-upstream`) tem
`initramfsName: /boot/initramfs-freebsd.img` — um valor de exemplo do
upstream nunca trocado. Isso faz o Calamares atual gravar o initramfs no
arquivo errado. `kiwi/root/etc/calamares/modules/dracut.conf` (novo)
corrige isso removendo essa chave; `lyra-installer-service` já roda
`dracut -f` correto desde o início.

**Fora de escopo, sinalizado**: remover os pacotes `calamares`/
`calamares-branding-upstream` do target (`packages.conf`'s `try_remove`) —
mexe com resolução de dependências do zypper sem um target real para
testar contra; fica para a auditoria de paridade da #44. `InstallConfig`
também ainda não tem campo de teclado — o layout usado é um mapeamento
fixo por locale (`pt_BR.UTF-8` → `br`, resto → `us`), assumido e dito
explicitamente no código, não um seletor de verdade.

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
novo. Li o código de verdade de novo em vez de assumir: o `main.py` real
do módulo `grubcfg` (compilado do pacote `calamares`), o
`/usr/sbin/shim-install` real (pacote `shim`) e o helper
`lyra-configure-btrfs-rollback` inteiro.

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
submenu de rollback aparecer) → remove `/etc/calamares` e o helper bash do
target.

**Achado real #2**: o `grubcfg` de verdade duplica `"splash"` —
`kernel_params: ["quiet","splash"]` do YAML mais a própria detecção
automática de `plymouth` do módulo (plymouth está instalado no target)
somam duas entradas, produzindo `GRUB_CMDLINE_LINUX_DEFAULT='quiet splash
splash'`. `lyra-installer-service` calcula o valor certo direto;
`kiwi/root/etc/calamares/modules/grubcfg.conf` também teve `"splash"`
removido de `kernel_params` (fica só `["quiet"]`), corrigindo o Calamares
ainda ativo pelo mesmo mecanismo — a detecção automática sozinha já
reintroduz `splash` uma vez, sem duplicar.

**`shim-install` real já resolve o fallback EFI sozinho**: sem
`--removable`, ele mesmo escreve `/boot/efi/EFI/boot/bootx64.efi` sempre
que esse caminho não existir ou pertencer a outra distro, e cria a entrada
NVRAM via `efibootmgr` internamente — não precisei reimplementar nada
disso, só invocar a ferramenta real do mesmo jeito que o Calamares já
invoca.

**O que continua sem confirmação, e por quê**: "Snapper lista/cria
snapshots após o primeiro boot", "rollback testado em VM" e "Secure Boot
ligado/desligado" exigem boot real, que este ambiente não tem como fazer.
A parte boa: **já existe tooling pronto pra isso** —
`kiwi/test/build-and-run-vm.sh --secure-boot` usa OVMF com chaves
Microsoft pré-inscritas, e `--boot-disk --secure-boot` reinicia um disco
já instalado preservando o NVRAM. `kiwi/README.md` já registra esse gap
("Validation status") — continua exatamente onde estava, não é novidade
desta sessão.

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
(`lyra-installer-service`) já existem, mas só como arcabouço de execução
segura — ainda sem nenhuma operação real de disco (isso é #40/#41/#42;
`operation::Operation` fica um enum vazio de propósito até lá). O que já
funciona: protocolo em JSON lines pelo stdin/stdout, revalidação do plano
contra um `StorageSnapshot` fresco antes de qualquer escrita (reaproveitando
o `PlanBuilder` de #39), allow-list de binários no `RealExecutor` (nunca
shell, nunca concatenação de string), cancelamento entre operações e
rollback best-effort em ordem reversa quando algo falha no meio.

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

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

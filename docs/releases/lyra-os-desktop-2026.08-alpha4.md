# Lyra OS 2026.08 Alpha 4 “Odisseia” — notas de lançamento

O Lyra OS Alpha 4 é um snapshot antecipado da edição desktop baseada no
openSUSE Leap 16.0 e GNOME 48+. Esta versão entrega a infraestrutura inicial
de internacionalização, o Lyra Installer em três idiomas selecionáveis e a
primeira onda de aplicativos próprios traduzidos.

Esta é uma versão **Alpha** destinada a testes e homologação. Não é recomendada
para produção nem para computadores que contenham dados sem backup.

## Destaques

- Lyra Installer em `en-US`, `pt-BR` e `es-ES`, com inglês como padrão e
  fallback;
- primeira onda de internacionalização de Vega, Fina e Sheliak;
- sessão live GNOME em Wayland e instalador nativo Rust/Tauri;
- sistema instalado em Btrfs, com Snapper, snapshots do Zypper e recuperação
  pelo GRUB;
- inicialização UEFI e suporte ao Secure Boot pelo `shim` do openSUSE;
- escolha entre ZRAM com Zstandard, swap em disco ou nenhuma memória virtual;
- Firefox, LibreOffice, VLC, Flatpak e Flathub configurados;
- inventário RPM, relatório do build e SBOMs CycloneDX/SPDX junto da ISO.

O repositório Packman não é habilitado. O fluxo opcional NVIDIA pelo Vega foi
transferido para a Alpha 5 e o driver proprietário não integra esta ISO.

## Requisitos

- computador ou máquina virtual `x86_64` com firmware UEFI;
- pelo menos 8 GiB de RAM recomendados;
- disco dedicado ou virtual com espaço suficiente para o sistema;
- conexão de rede recomendada para atualizações e serviços online;
- mídia USB ou unidade virtual com capacidade superior ao tamanho da ISO.

## Instalação

1. Inicialize pela ISO em modo UEFI.
2. Aguarde a sessão live GNOME e a abertura automática do Lyra Installer.
3. Revise idioma, teclado, fuso horário, hostname, armazenamento e memória
   virtual.
4. Crie o usuário administrador e confira o plano antes da confirmação final.
5. Ao concluir, remova a mídia e reinicie no sistema instalado.

O modo suportado nesta Alpha é a instalação direta em disco inteiro. Confira
cuidadosamente o dispositivo e as partições que o plano informa que serão
removidas. Não há retomada automática depois da primeira operação destrutiva.

## Limitações conhecidas

- criação ou reaproveitamento de RAID e LVM não está disponível;
- particionamento manual e instalação lado a lado não possuem cobertura de
  release;
- Beam, Sulafat, Aladfar e os componentes restantes entram na segunda onda de
  internacionalização planejada para a Alpha 5;
- o catálogo `zh-CN` está preservado na fonte, mas a opção permanece
  desativada nesta imagem até que o fluxo completo seja validado;
- o fluxo NVIDIA G06 ainda não é suportado e permanece fora da ISO padrão;
- a matriz inicial de hardware físico é limitada e algumas combinações de GPU,
  Wi-Fi, armazenamento ou firmware podem apresentar problemas;
- por ser Alpha, detalhes da interface e do instalador podem mudar antes da
  Beta.

Não há credencial padrão. A senha é definida durante a instalação, a conta
`root` permanece bloqueada para login direto e o usuário criado recebe acesso
administrativo pelo grupo `wheel`.

## Integridade da imagem

Arquivo esperado:

```text
lyra-os.x86_64-2026.08-alpha4.iso
```

Verifique o checksum distribuído junto da ISO:

```sh
sha256sum -c lyra-os.x86_64-2026.08-alpha4.iso.sha256
```

Por decisão registrada na ADR 0005, a Alpha 4 é publicada com SHA-256, mas sem
assinatura GPG da ISO. A assinatura de artefatos começa na Beta 1. Assinaturas
de pacotes e repositórios continuam obrigatórias e verificadas no build.

## Relato de problemas

Inclua o modelo da máquina ou configuração da VM, modo de firmware, etapa da
falha e logs disponíveis. Não publique senhas, chaves, endereços privados ou
outros dados sensíveis. O contrato completo de go/no-go e as evidências
exigidas estão em `docs/release-gate.md`.

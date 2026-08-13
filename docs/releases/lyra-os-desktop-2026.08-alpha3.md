# Lyra OS 2026.08 Alpha 3 “Odisseia” — notas de lançamento

O Lyra OS Alpha 3 é uma imagem desktop de avaliação baseada no openSUSE Leap
16.0, com GNOME 48+, identidade visual Odisseia e integração com os aplicativos
do ecossistema Lyra.

Esta é uma versão **Alpha** destinada a testes e homologação. Não é recomendada
para produção nem para computadores que contenham dados sem backup.

## Destaques

- sessão live GNOME em Wayland;
- Lyra Installer nativo em Rust/Tauri como único instalador da imagem;
- sistema instalado em Btrfs, com Snapper e snapshots do Zypper;
- recuperação por snapshots no menu do GRUB;
- inicialização UEFI e suporte ao Secure Boot pelo `shim` do openSUSE;
- escolha entre ZRAM com Zstandard, swap em disco ou nenhuma memória virtual;
- `sudo` autentica com a senha do usuário administrador, sem solicitar a senha
  da conta root bloqueada;
- Firefox, GNOME Software, Flatpak e Flathub configurados;
- Vega, Sheliak, Fina, Chord, Beam e Sulafat integrados ao desktop;
- tema, ícones, GRUB e wallpapers Nebula da identidade Lyra;
- Bluetooth e suporte à gravação de tela instalados explicitamente;
- `lyra-report` para diagnóstico local, voluntário e sem telemetria automática;
- inventário RPM e SBOMs CycloneDX/SPDX disponíveis junto da ISO.

O repositório Packman não é habilitado.

## Requisitos

- computador ou máquina virtual `x86_64`;
- firmware UEFI;
- pelo menos 8 GiB de RAM recomendados para testar confortavelmente a sessão
  live e o instalador;
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

- criação ou reaproveitamento de RAID e LVM ainda não está disponível no
  instalador; a interface oferece somente disco inteiro com layout direto;
- particionamento manual e instalação lado a lado ainda não possuem cobertura
  de release;
- codecs multimídia adicionais ainda precisam ser publicados nos repositórios
  do Lyra; o Packman não é usado como alternativa;
- a matriz inicial de hardware físico é limitada e algumas combinações de GPU,
  Wi-Fi, controladora de armazenamento ou firmware podem apresentar problemas;
- por ser Alpha, detalhes da interface e do fluxo do instalador podem mudar
  antes da Beta.

Não há credencial padrão. A senha é definida durante a instalação, a conta
`root` permanece bloqueada para login direto e o usuário criado recebe acesso
administrativo pelo grupo `wheel`.

## Integridade da imagem

Arquivo esperado:

```text
lyra-os.x86_64-2026.08-alpha3.iso
```

Verifique o arquivo usando o checksum distribuído junto da ISO:

```sh
sha256sum -c lyra-os.x86_64-2026.08-alpha3.iso.sha256
```

Por decisão registrada na ADR 0005, a Alpha 3 é publicada com SHA-256, mas sem
assinatura GPG da ISO. A criação e o uso obrigatório da chave de release
começam na Beta 1. Essa exceção não se aplica aos RPMs: assinaturas de pacotes e
repositórios continuam obrigatórias e verificadas durante o build.

## Relato de problemas

Ao relatar um problema, inclua o modelo da máquina ou configuração da VM, modo
de firmware, etapa da falha e os logs disponíveis. Não publique senhas, chaves,
endereços privados ou outros dados sensíveis.

O contrato completo de go/no-go e as evidências exigidas estão em
`docs/release-gate.md`.

# Lyra OS 2026.08 Alpha 6 “Odisseia” — notas de lançamento

O Lyra OS Alpha 6 é uma versão antecipada do desktop baseado no openSUSE
Leap 16.0 e GNOME 48+. Ela prioriza atualizações previsíveis, recuperação e
uma experiência inicial mais clara.

Esta versão **Alpha** destina-se a testes e homologação. Não é recomendada
para produção nem para computadores com dados sem backup.

## Destaques

- Lyra Upgrade para atualizações dentro da mesma release, com planejamento
  sem privilégio, confirmação antes do Polkit e estado persistente;
- execução observável, console sanitizado, diagnóstico e caminhos orientados
  de recuperação e rollback;
- Lyra Welcome com telas de apresentação, conectividade Wi-Fi e acesso ao Vega;
- pilha ALSA de usuário declarada explicitamente na imagem desktop;
- interfaces do instalador, Welcome e Upgrade em `en-US`, `pt-BR` e `es-ES`;
- base openSUSE Leap 16.0, GNOME, Btrfs, Snapper e recuperação pelo GRUB.

O upgrade entre versões permanece fora desta Alpha e será tratado na Alpha 7.
O Algedi não integra a imagem candidata desta versão.

## Requisitos e instalação

- computador ou máquina virtual `x86_64` com firmware UEFI;
- 8 GiB de RAM recomendados;
- disco dedicado ou virtual com espaço suficiente;
- conexão de rede recomendada para atualizações.

Inicialize a ISO em modo UEFI, aguarde a sessão live e siga o Lyra Installer.
O modo coberto por esta Alpha é a instalação em disco inteiro. Confira o
dispositivo e o plano antes da confirmação destrutiva.

## Limitações conhecidas

- RAID, LVM, particionamento manual e instalação lado a lado não possuem
  cobertura de release;
- upgrade entre releases ainda não é suportado;
- a matriz de hardware físico permanece limitada;
- por ser Alpha, interfaces e fluxos ainda podem mudar antes da Beta 1.

Não há credencial padrão. A senha é definida durante a instalação, a conta
`root` permanece bloqueada para login direto e o usuário administrador usa o
grupo `wheel`.

## Integridade

Arquivo esperado:

```text
lyra-os.x86_64-2026.08-alpha6.iso
```

Verifique o checksum fornecido junto da ISO:

```sh
sha256sum -c lyra-os.x86_64-2026.08-alpha6.iso.sha256
```

Conforme a ADR 0005, a Alpha 6 usa SHA-256 sem assinatura GPG destacada da
ISO. Pacotes e repositórios continuam obrigatoriamente assinados. A assinatura
dos artefatos de release passa a ser obrigatória na Beta 1.

## Relato de problemas

Informe modelo da máquina ou configuração da VM, firmware, etapa da falha e
logs disponíveis. Não publique senhas, chaves ou dados pessoais. O contrato de
go/no-go está em `docs/release-gate.md`.

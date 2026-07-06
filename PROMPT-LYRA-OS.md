# PROMPT DE IMPLEMENTAÇÃO — LYRA OS

> **Versão:** 2.0
> **Status:** Especificação de build congelada, pronta para implementação
> **Escopo:** Este documento é a fonte única de verdade para gerar o ISO instalável do Lyra OS. Todas as decisões abaixo estão fechadas. Um implementador (humano ou agente) deve seguir literalmente as escolhas listadas, sem re-questioná-las.

---

## 1. Visão Geral

**Lyra OS** é uma distribuição Linux de propósito geral voltada para o **usuário final não-técnico**, com foco em experiência polida, previsibilidade e recuperação segura. É um **projeto independente**, sem vínculo comercial ou técnico com qualquer outra entidade.

- **Slogan:** *Harmonia. Performace. Liberdade.*
- **Base:** Arch Linux (rolling release, curada)
- **Público:** desktops e notebooks pessoais, uso doméstico e produtividade
- **Filosofia:** "vanilla-first" — o Lyra OS respeita as convenções upstream do GNOME e não substitui nem duplica funcionalidades já presentes no ambiente. Ele adiciona apenas o que falta.

---

## 2. Identidade

| Item | Valor |
|---|---|
| Nome oficial | `Lyra OS` |
| Nome curto | `lyra` |
| Codinome do release | (a definir por versão) |
| Slogan | Harmonia. Performance. Liberdade. |
| Logo | Lira estilizada, degradê azul-safira → violeta, estrela no topo, 4 cordas |
| Nome de host padrão | `lyra` |
| ID de release (`os-release`) | `ID=lyra`, `ID_LIKE=arch` |

---

## 3. Base do Sistema

### 3.1 Kernel

- **Kernel padrão:** `linux-zen`
- **Kernel LTS:** `linux-lts` instalado em paralelo como fallback (selecionável no GRUB)
- **Firmware:** `linux-firmware` completo
- **Microcode:** `intel-ucode` e `amd-ucode` (aplicados automaticamente pelo GRUB conforme CPU detectada)

### 3.2 Bootloader

- **GRUB** (BIOS e UEFI), com tema visual Lyra
- Entradas geradas automaticamente para o kernel padrão, LTS e snapshots do Snapper (`grub-btrfs`)

### 3.3 Filesystem

- **Padrão de instalação:** **Btrfs** com subvolumes:
  - `@` → `/`
  - `@home` → `/home`
  - `@var_log` → `/var/log`
  - `@var_cache` → `/var/cache`
  - `@snapshots` → `/.snapshots`
- **Snapshots:** **Snapper** configurado com política automática (pré e pós transações Pacman) e integração com GRUB (`grub-btrfs`)
- **Swap:** arquivo de swap em `@swap` (zram como acelerador via `zram-generator`)
- **Boot:** partição EFI FAT32 (`/boot/efi`), 512 MiB

### 3.4 Init e serviços

- **Init:** `systemd`
- **Rede:** `NetworkManager`
- **Firewall:** `firewalld` (habilitado por padrão, zona `home`)
- **Áudio:** `PipeWire` + `wireplumber` (substituindo PulseAudio e JACK)
- **Bluetooth:** `bluez` + `bluez-utils`, habilitado por padrão
- **Impressão:** `cups` + `system-config-printer`
- **Time sync:** `systemd-timesyncd`

### 3.5 Locale e teclado

- **Locale padrão:** `pt_BR.UTF-8`
- **Segundo locale gerado:** `en_US.UTF-8`
- **Timezone padrão:** `America/Sao_Paulo` (ajustável no Calamares)
- **Teclado padrão:** `br-abnt2` (ajustável no Calamares)

---

## 4. Ambiente Gráfico — GNOME Vanilla

### 4.1 Servidor gráfico

- **Padrão:** Wayland
- **Fallback X11:** disponível na tela de login (Xorg mantido instalado)
- **Display manager:** `gdm`

### 4.2 GNOME

- Versão upstream mais recente disponível no Arch, **sem forks nem patches**.
- Pacote base: grupo `gnome` (o meta-grupo completo do Arch), com remoções seletivas listadas em §6.
- **Nenhum tuning invasivo do shell.** Layout, atalhos, comportamento de janelas e Activities Overview permanecem exatamente como no GNOME upstream.

### 4.3 Extensões GNOME pré-instaladas

Apenas o **mínimo estritamente necessário** para aplicar o tema visual e suportar bandejas de aplicativos:

| Extensão | Pacote | Motivo |
|---|---|---|
| **User Themes** | `gnome-shell-extension-user-theme` | Necessária para aplicar o shell theme `Lyra-Dark` |
| **AppIndicator / KStatusNotifierItem Support** | `gnome-shell-extension-appindicator` | Compatibilidade com apps que usam bandeja legada (Electron, Discord, Steam etc.) |

Ambas devem estar **habilitadas por padrão** para todos os usuários novos (via dconf defaults — ver §5.4).

Nenhuma outra extensão é pré-instalada. O Extension Manager (`extension-manager`) fica disponível como app opcional para o usuário adicionar por conta própria.

---

## 5. Personalização Visual

O Lyra OS aplica identidade visual **exclusivamente por temas, ícones, wallpapers e dconf defaults**. Não modifica CSS do shell nem sobrescreve arquivos do GNOME.

### 5.1 Wallpapers

- **Origem:** pasta `wallpaper/` fornecida com o projeto
- **Instalação:** todos os arquivos da pasta são copiados para `/usr/share/backgrounds/lyra/`
- **Wallpaper padrão:** `default.png` (arquivo obrigatório dentro da pasta `wallpaper/`)
- **Registro no GNOME:** criar arquivo XML de coleção em `/usr/share/gnome-background-properties/lyra.xml` listando todos os wallpapers, para que apareçam na aba **Configurações → Fundo do Ecrã**

Exemplo de `lyra.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
<wallpapers>
  <wallpaper deleted="false">
    <name>Lyra Default</name>
    <filename>/usr/share/backgrounds/lyra/default.png</filename>
    <options>zoom</options>
    <pcolor>#1a1a2e</pcolor>
    <scolor>#1a1a2e</scolor>
    <shade_type>solid</shade_type>
  </wallpaper>
  <!-- demais wallpapers listados um por um -->
</wallpapers>
```

### 5.2 Shell Theme

- **Nome:** `Lyra-Dark`
- **Arquivo:** `Lyra-Dark.tar.xz` (fornecido)
- **Instalação:**
  - Extrair para `/usr/share/themes/`
  - Resultado esperado: `/usr/share/themes/Lyra-Dark/gnome-shell/gnome-shell.css` (mais os demais recursos)
- **Aplicação:** via dconf key `org.gnome.shell.extensions.user-theme name` = `'Lyra-Dark'`

### 5.3 Ícones

- **Nome:** `Lyra-Icons-v2`
- **Arquivo:** `Lyra-Icons-v2.tar.xz` (fornecido)
- **Instalação:**
  - Extrair para `/usr/share/icons/`
  - Resultado esperado: `/usr/share/icons/Lyra-Icons-v2/index.theme` (mais os subdiretórios de ícones)
  - Rodar `gtk-update-icon-cache /usr/share/icons/Lyra-Icons-v2/` como passo de build
- **Aplicação:** via dconf key `org.gnome.desktop.interface icon-theme` = `'Lyra-Icons-v2'`

### 5.4 dconf defaults (aplicados a todos os usuários novos)

Criar o database `/etc/dconf/db/lyra.d/` com o arquivo `00-appearance`:

```ini
[org/gnome/desktop/interface]
color-scheme='prefer-dark'
icon-theme='Lyra-Icons-v2'
gtk-theme='Adwaita-dark'
cursor-theme='Adwaita'
font-name='Cantarell 11'

[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/lyra/default.png'
picture-uri-dark='file:///usr/share/backgrounds/lyra/default.png'
picture-options='zoom'

[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/lyra/default.png'

[org/gnome/shell]
disable-user-extensions=false
enabled-extensions=['user-theme@gnome-shell-extensions.gcampax.github.com', 'appindicatorsupport@rgcjonas.gmail.com']

[org/gnome/shell/extensions/user-theme]
name='Lyra-Dark'
```

E o arquivo de perfil `/etc/dconf/profile/user`:

```
user-db:user
system-db:lyra
```

Ao final do build, executar `dconf update`.

### 5.5 Plymouth (boot splash)

- **Habilitado** por padrão
- Tema Plymouth customizado com o logo Lyra (arquivo separado, fora do escopo deste prompt — o build deve apenas reservar o hook e o pacote `plymouth`)

### 5.6 GRUB theme

- Tema visual do GRUB com o logo Lyra em fundo escuro (arquivo separado — reservar hook em `/boot/grub/themes/lyra/`)

---

## 6. Software Pré-instalado

### 6.1 Aplicativos principais (obrigatórios)

Suite Atelier e finanças pessoais, pré-instaladas via AUR (ver §10 para a estratégia de canais):

- **Prosa** — editor de texto (pacote AUR: `prosa`)
- **Calco** — planilhas (pacote AUR: `calco`)
- **Pulso** — apresentações (pacote AUR: `pulso`)
- **Fina** — finanças pessoais (pacote AUR)

### 6.2 Navegador

- **Firefox** (`firefox`, `firefox-i18n-pt-br`)

### 6.3 Multimídia e utilitários GNOME (mantidos)

- `nautilus` (arquivos)
- `gnome-terminal`
- `gnome-text-editor`
- `gnome-calculator`
- `gnome-calendar`
- `gnome-clocks`
- `gnome-weather`
- `gnome-system-monitor`
- `gnome-disk-utility`
- `gnome-screenshot`
- `loupe` (visualizador de imagens)
- `totem` (vídeo)
- `snapshot` (câmera)
- `evince` (PDF)
- `file-roller` (compactação)
- `extension-manager` (disponível mas não como padrão do usuário)

### 6.4 Codecs e fontes

- `gstreamer` completo (`gst-plugins-base`, `gst-plugins-good`, `gst-plugins-bad`, `gst-plugins-ugly`, `gst-libav`)
- Fontes: `noto-fonts`, `noto-fonts-emoji`, `noto-fonts-cjk`, `ttf-liberation`, `ttf-dejavu`, `cantarell-fonts`

### 6.5 Componentes Lyra

- **Lyrae** (painel de controle) — ver §9
- **lyraed** (daemon privilegiado) — ver §9

### 6.6 Remoções do grupo `gnome`

Remover do meta-grupo:

- `gnome-tour` (tela de boas-vindas upstream — Lyra terá a própria, futura)
- `gnome-music` (opcional; o público-alvo raramente usa)
- `gnome-contacts` (opcional; sem conta configurada, é dead weight)
- `epiphany` (browser upstream; Firefox é o padrão)

Manter todo o resto do grupo.

### 6.7 O que **NÃO** vem pré-instalado

- Nenhum pacote AUR além dos listados em §6.1
- Nenhuma suite Office alternativa (LibreOffice, OnlyOffice) — o padrão é Atelier
- Nenhum cliente de e-mail (Geary/Thunderbird ficam disponíveis via Flatpak/Pacman, mas não vêm por padrão)

---

## 7. Instalador — Calamares

- **Instalador:** Calamares
- **Idioma padrão do instalador:** Português (Brasil), com opção de troca
- **Módulos habilitados (ordem):**
  1. Welcome
  2. Locale
  3. Keyboard
  4. Partition (com preset Btrfs + subvolumes automático)
  5. Users
  6. Summary
  7. (fase de instalação)
  8. Finished
- **Branding:** logo Lyra, wallpaper `default.png` como fundo do instalador
- **Filesystem padrão sugerido:** Btrfs com layout descrito em §3.3
- **LVM/LUKS:** disponíveis mas não pré-selecionados; opção de encriptação de disco visível
- **Automount pós-instalação:** habilitado

---

## 8. Detecção Automática de Hardware

Executada durante a instalação (via módulo Calamares customizado ou hook pós-instalação):

### 8.1 GPU

Detecção automática de GPU NVIDIA e instalação do driver adequado:

| GPU detectada | Driver instalado |
|---|---|
| NVIDIA Turing (RTX 20xx) ou mais nova | `nvidia-open-dkms` + `nvidia-utils` |
| NVIDIA Maxwell/Pascal (GTX 9xx / GTX 10xx) | `nvidia-580xx-dkms` (série legado suportada) + `nvidia-utils` |
| NVIDIA anterior a Maxwell | `nouveau` (fallback, sem prompt) |
| AMD | `mesa` + `vulkan-radeon` (default) |
| Intel | `mesa` + `vulkan-intel` (default) |

A detecção usa `lspci -nnk | grep -A2 VGA` e a lista de PCI IDs por geração NVIDIA (mantida no repositório do projeto como `hwdb/nvidia-generations.json`).

### 8.2 Outros

- Wi-Fi: `linux-firmware` cobre a maioria; drivers Broadcom (`broadcom-wl-dkms`) instalados sob demanda se detectado
- Impressoras: `cups` já habilitado; drivers Gutenprint pré-instalados

---

## 9. Componentes Lyra — Lyrae e lyraed

### 9.1 Papel dentro do Lyra OS

- **Lyrae** e **lyraed** são componentes de primeira classe do Lyra OS.
- **Não substituem** o GNOME Settings — **complementam**. Tudo que o GNOME Settings já faz bem (aparência, som, mouse, energia, notificações, contas online, etc.) permanece com ele.
- Lyrae cobre exclusivamente o que o GNOME não oferece nativamente ou não oferece de forma polida para usuário final:
  - Contas/Usuários (gestão avançada, sudoers)
  - Rede (visão consolidada, incluindo firewall)
  - Firewall (interface amigável para `firewalld`)
  - Hardware e Drivers (especialmente troca de driver NVIDIA)
  - Kernel (trocador entre `linux-zen` e `linux-lts`)
  - Atualizações + Pontos de Restauração (Snapper)
  - Data/Hora/Idioma (consolidado)
  - Sobre (informações do Lyra OS)

### 9.2 Arquitetura

- **Lyrae:** Electron + TypeScript, **rodando como usuário não-privilegiado**
- **lyraed:** daemon em Go, rodando como root, exposto na **system bus** do D-Bus sob o nome `com.lyraos.Lyraed`
- Comunicação Lyrae ↔ lyraed exclusivamente via **D-Bus**, com autorização mediada por **polkit**
- **Nenhuma parte da UI roda como root.** Nenhuma ação privilegiada é executada sem passar por policy do polkit.

### 9.3 Integração no ISO

- Ambos empacotados como pacotes Pacman locais (`lyrae`, `lyraed`) no repositório do projeto
- `lyraed.service` (unit systemd) habilitado por padrão
- Políticas polkit instaladas em `/usr/share/polkit-1/actions/com.lyraos.lyraed.policy`
- Ícone e desktop entry do Lyrae em `/usr/share/applications/lyrae.desktop`, integrado ao Activities Overview

*(Os specs de build separados de Lyrae e lyraed permanecem válidos — este documento os referencia, não os redefine.)*

---

## 10. Canais de Software

### 10.1 Pacman

- **Repositórios habilitados:** `core`, `extra`, `multilib`
- **Repositório do projeto:** `lyra` (adicional, prioridade acima do `extra`), servindo:
  - `lyrae`
  - `lyraed`
  - Meta-pacote `lyra-desktop` (dependências de tudo listado em §6)
  - Wallpapers e temas empacotados: `lyra-backgrounds`, `lyra-themes`
- Assinatura: chave GPG do projeto, incluída no keyring do build

### 10.2 AUR

- **Habilitado por padrão**, mas **acessado exclusivamente via CLI (`paru` pré-instalado)** — sem GUI dedicada a AUR no primeiro release.
- Curadoria: apenas os pacotes AUR listados em §6.1 são pré-instalados no ISO. Instalações adicionais ficam a critério do usuário.

### 10.3 Flatpak

- **Flathub** habilitado por padrão
- **GNOME Software** funciona como store principal, cobrindo Flatpak + Pacman via plugin

### 10.4 Snap

- **Não suportado.** Não instalar `snapd` no ISO.

---

## 11. Estrutura do Build do ISO

Ferramenta: **archiso**.

Layout esperado do diretório de build:

```
lyra-iso/
├── profiledef.sh
├── packages.x86_64            # lista consolidada de pacotes Pacman
├── pacman.conf                # com repositório `lyra` adicionado
├── airootfs/                  # rootfs live
│   ├── etc/
│   │   ├── skel/              # perfil default de usuário
│   │   ├── dconf/
│   │   │   ├── db/lyra.d/00-appearance
│   │   │   └── profile/user
│   │   ├── systemd/system/    # links para services habilitadas por default
│   │   └── os-release
│   ├── usr/
│   │   ├── share/
│   │   │   ├── backgrounds/lyra/       ← conteúdo da pasta wallpaper/
│   │   │   ├── themes/Lyra-Dark/       ← extraído de Lyra-Dark.tar.xz
│   │   │   ├── icons/Lyra-Icons-v2/    ← extraído de Lyra-Icons-v2.tar.xz
│   │   │   └── gnome-background-properties/lyra.xml
├── assets/                    # inputs do projeto (não vão para o ISO diretamente)
│   ├── wallpaper/             ← pasta original com default.png e demais
│   ├── Lyra-Dark.tar.xz
│   └── Lyra-Icons-v2.tar.xz
└── build.sh                   # orquestra: extrai assets → popula airootfs → chama mkarchiso
```

### 11.1 Passos obrigatórios do `build.sh`

1. Copiar `assets/wallpaper/*` para `airootfs/usr/share/backgrounds/lyra/`
2. Extrair `assets/Lyra-Dark.tar.xz` em `airootfs/usr/share/themes/`
3. Extrair `assets/Lyra-Icons-v2.tar.xz` em `airootfs/usr/share/icons/`
4. Gerar `airootfs/usr/share/gnome-background-properties/lyra.xml` a partir do conteúdo de `wallpaper/`
5. Rodar `gtk-update-icon-cache` sobre o tema de ícones (dentro do chroot pós-instalação)
6. Rodar `dconf update` (dentro do chroot pós-instalação)
7. Habilitar systemd units: `gdm`, `NetworkManager`, `firewalld`, `bluetooth`, `cups.socket`, `lyraed`
8. Executar `mkarchiso -v -w work -o out .`

### 11.2 Validação pós-build

Checklist mínimo antes de considerar o ISO válido:

- [ ] Boot no live USB inicia GDM com wallpaper `default.png` visível
- [ ] Shell theme `Lyra-Dark` aplicado (barra superior escura estilizada)
- [ ] Tema de ícones `Lyra-Icons-v2` aplicado (visível no Nautilus)
- [ ] Extensões User Themes e AppIndicator ativas
- [ ] Calamares abre em português com branding Lyra
- [ ] Instalação em Btrfs cria os subvolumes de §3.3
- [ ] `snapper list` funciona após instalação
- [ ] Firefox, Prosa, Calco, Pulso e Fina no Activities Overview
- [ ] `systemctl status lyraed` reporta ativo
- [ ] Lyrae abre e conecta ao lyraed sem erros de polkit
- [ ] `os-release` mostra `ID=lyra`

---

## 12. Convenções e Restrições

### 12.1 Vanilla-first

- **Nenhum patch no shell, no mutter ou nos apps GNOME.**
- Toda customização visual deve ser feita via tema, ícones, dconf ou wallpaper — nunca via edição de arquivos upstream.

### 12.2 Sem duplicação

- Lyrae **não replica** telas do GNOME Settings.
- Se algo é bem-resolvido pelo GNOME upstream, Lyra OS usa o GNOME upstream.

### 12.3 Privilégio mínimo

- UI nunca roda como root.
- Toda ação privilegiada passa por polkit + lyraed.

### 12.4 Reprodutibilidade

- O build deve ser **reprodutível a partir do repositório**: dado o mesmo commit e os mesmos assets, deve gerar um ISO funcionalmente equivalente.
- Versões de pacotes AUR (Prosa, Calco, Pulso, Fina) fixadas em `packages.aur.lock` no build.

### 12.5 Formatos de asset

- Wallpapers: PNG, resolução mínima 1920×1080, preferencialmente 3840×2160
- Temas: `.tar.xz` contendo diretório raiz com o nome canônico (`Lyra-Dark/`, `Lyra-Icons-v2/`)
- O build **falha explicitamente** se `assets/wallpaper/default.png` não existir

---

## 13. Entregáveis

Ao final da execução deste prompt, o repositório do Lyra OS deve conter:

1. Diretório `lyra-iso/` estruturado conforme §11
2. `build.sh` funcional e idempotente
3. `packages.x86_64` consolidado
4. `pacman.conf` com repositório `lyra` configurado
5. dconf database `lyra.d/00-appearance` conforme §5.4
6. `lyra.xml` de wallpapers gerado
7. ISO gerado em `out/lyra-<versão>-x86_64.iso`
8. Checksum SHA-256 do ISO
9. `README.md` no repositório, em português, explicando como rodar o build

---

## 14. Fora de Escopo (para versões futuras)

Não implementar nesta versão:

- Gerenciador de pacotes gráfico próprio ("nosso Pamac")
- Tela de boas-vindas customizada (substituto do `gnome-tour`)
- Assinatura de kernel para Secure Boot
- Imagens ARM (aarch64)
- Live CD com persistência

Cada um destes itens receberá seu próprio prompt de implementação quando priorizado.

---

**Fim da especificação.**

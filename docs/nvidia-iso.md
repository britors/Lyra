# ISO NVIDIA (deliverable pós-release)

Este documento é o rascunho de arquitetura da variante de ISO com o driver
proprietário NVIDIA pré-instalado e pré-configurado. Ele existe para orientar
a implementação quando o ciclo começar — **não autoriza começar a
implementação agora**. Conforme `PROMPT-LYRA-OS.md`, a variante NVIDIA fica
para depois da publicação da Lyra OS 1.0 (alvo interno em janeiro de 2027,
com buffer até aproximadamente 16/02/2027), e `docs/image-builds.md`
já a trata como "a separate optional deliverable" que não pode introduzir um
flavor de imagem na OBS nem bloquear a ISO padrão. Este rascunho não muda
nenhuma dessas decisões.

## Escopo

A ISO padrão já decidiu, deliberadamente, **não** detectar nem instalar
driver de GPU NVIDIA — isso fica a cargo do usuário via Vega
(`PROMPT-LYRA-OS.md`, seção "Repositórios e canais de pacotes"). A ISO NVIDIA
inverte essa decisão só para si mesma: mesma base (Leap 16, kernel-default,
GNOME, Btrfs/Snapper, Lyra Installer, branding Lyra), acrescentando o driver
proprietário (família G06) já instalado e configurado no primeiro boot, sem
passo manual do usuário.

Fora de escopo até decisão em contrário:
- suporte à pilha aberta (`nouveau`/`nvidia-open`) — já é coberto pela ISO
  padrão e por `docs/hardware-matrix.md`, não depende desta variante;
- laptops híbridos Intel+NVIDIA (Optimus/PRIME) — ver "Questões em aberto";
- arquitetura ARM64 — mesma exclusão da v1 padrão.

## O que muda em relação à ISO padrão

| Item | ISO padrão | ISO NVIDIA |
|---|---|---|
| Driver GPU NVIDIA | ausente, instalável depois via Vega | pré-instalado e configurado |
| Fonte do pacote do driver | n/a | a definir — ver "Questões em aberto" |
| Perfil/target KIWI | único (`config.xml` sem `<profiles>`) | segundo profile reaproveitando a base |
| Nome/volid da imagem | `lyra-os` / `LYRA_OS_...` | `lyra-os-nvidia` / volid próprio |
| Gate de release | `docs/release-gate.md` (P0–P3, bloqueante) | gate próprio, não bloqueante para a ISO padrão |
| Cobertura de hardware | Intel/AMD obrigatório (`hardware-matrix.md`) | GPU NVIDIA real obrigatória, adicional |

## Mecânica de build (KIWI)

`kiwi/config.xml` hoje não tem `<profiles>` — é uma única imagem. A rota mais
próxima da arquitetura atual é o mecanismo de profiles nativo do KIWI:
um profile-base comum (pacotes/branding/instalador atuais) e um profile
`nvidia` que soma o(s) pacote(s) kmp do driver, ajusta `name`/`displayname`/
`volid` e mantém o resto idêntico. `scripts/image-build.py` precisaria de uma
flag de profile para selecionar o alvo de export/validate sem duplicar o
arquivo inteiro. Isso preserva o limite já documentado em
`docs/image-builds.md`: a OBS continua fornecendo só RPMs, o KIWI continua
rodando localmente/CI a partir de um commit limpo, e o SourceForge continua
sendo o único ponto de distribuição do binário ISO.

## Fonte do driver e assinatura de pacote

A política atual evita dependência de terceiros para o que a Lyra já
consegue empacotar sozinha (ex.: codecs multimídia via OBS do Lyra em vez do
Packman). O mesmo princípio sugere um novo projeto OBS
(`home:rodrigosbrito:lyra-nvidia`, a criar) republicando/rebuild dos pacotes
`kmp-nvidia`/`x11-video-nvidiaG06` a partir da fonte oficial NVIDIA para
openSUSE, assinado com a mesma chave já usada pelos demais projetos
(`obs/projects.toml`, `[signing] fingerprint = "399218A6E088C4053F4533BE58097F767EDCA82E"`).
A alternativa — apontar `image-build.toml`/`kiwi/config.xml` direto para o
repositório oficial da NVIDIA — é mais simples, mas foge do padrão de
proveniência e assinatura que `docs/obs-release.md` e o gate de release
exigem hoje para tudo que entra na ISO. Isso é uma escolha em aberto, não uma
decisão.

## Secure Boot — ponto crítico, não decidido

O caminho de Secure Boot da ISO padrão (`docs/installer-architecture.md`,
seção "GRUB, shim (Secure Boot) e rollback via Snapper") assume módulos de
kernel assinados pela cadeia shim/Microsoft/SUSE já confiável. O módulo
NVIDIA proprietário é out-of-tree: sem assinatura reconhecida por essa
cadeia, ele não carrega com Secure Boot ativo. Três rotas possíveis, cada
uma com trade-off diferente, nenhuma escolhida ainda:

1. **kmp já assinado pela SUSE/comunidade**, se existir para a versão de
   Leap 16 alvo — mantém o mesmo modelo de confiança da ISO padrão, mas
   depende de disponibilidade fora do nosso controle. **Validado como real
   nesta rota** (2026-08-11): `nvidia-open-driver-G06-signed-kmp-default`
   carregou sem nenhum enrollment manual de MOK na máquina física de teste
   do Rodrigo (Secure Boot ligado) — a disponibilidade não é hipotética
   pelo menos para a família G06 (Turing e mais novo) em Leap 16.0. Não
   elimina a decisão (ainda depende de disponibilidade contínua, fora do
   nosso controle), mas tira a incerteza de "existe de verdade?".
2. **MOK próprio da Lyra**, gerado e usado para assinar o módulo no build
   (OBS ou KIWI), com enrollment do MOK feito pelo Lyra Installer só neste
   profile — replica o padrão akmod/DKMS de outras distros, mas adiciona uma
   tela e um reboot extra de enrollment que a ISO padrão não tem, e uma nova
   chave privada para proteger e rotacionar.
3. **Secure Boot desabilitado por padrão nesta variante**, documentado como
   trade-off aceito — mais simples de implementar, mas contradiz a postura
   atual de Secure Boot ligado por padrão e exigiria seu próprio texto de
   aviso no instalador/release notes.

Esta escolha bloqueia a implementação e precisa ser decidida antes de tocar
em código.

## Kernel e módulo em lockstep

`kmp-nvidia` é compilado contra uma ABI de kernel específica. Um `zypper dup`
que atualiza `kernel-default` sem uma `kmp-nvidia` correspondente já publicada
deixa a máquina sem aceleração de GPU (ou sem boot gráfico) até o pacote
alcançar o kernel novo. A ISO NVIDIA precisa de uma política explícita para
isso — travar o par kernel+kmp numa mesma transação do Vega, ou publicar o
kmp novo antes de liberar o kernel novo no canal Lyra — análoga à política já
descrita em `PROMPT-LYRA-OS.md` para upgrades de ponto de versão do Leap
(testar os repositórios Lyra contra o alvo antes de liberar a migração).

**Achado real, não hipotético** (2026-08-11, na própria máquina física de
teste do Rodrigo — GTX 1650 Mobile/TU117, híbrida com Intel): o mesmo tipo
de problema existe um nível abaixo, entre o **kmp e os pacotes de
userspace/firmware**, não só entre kernel e kmp. `zypper install
nvidia-open-driver-G06-signed-kmp-default` sozinho trouxe o kernel module
na versão `580.159.03`, mas deixou `nvidia-video-G06`/`nvidia-gl-G06`/
`nvidia-common-G06` parados em `570.172.08` (já instalados antes, de uma
tentativa anterior). O firmware GSP fica em
`/usr/lib/firmware/nvidia/<versão>/gsp_tu10x.bin`, organizado por versão —
com userspace em 570 e kmp em 580, o firmware certo (580) nem estava no
disco. Sintoma: `nvidia`/`nvidia-drm`/`nvidia-modeset` carregam
normalmente (aparecem no `lsmod`, PCI vinculado ao driver certo), **sem
nenhum erro visível pro usuário** — só em
`dmesg`/`journalctl` aparece a causa real:

```
nvidia 0000:01:00.0: Direct firmware load for nvidia/580.159.03/gsp_tu10x.bin failed with error -2
[drm:nv_drm_dev_load [nvidia_drm]] *ERROR* [nvidia-drm] Failed to allocate NvKmsKapiDevice
```

Sem essa entrada DRM, nenhuma saída de vídeo da GPU dedicada aparece (no
caso do Rodrigo, o monitor externo por HDMI, cabeado na NVIDIA nesse
notebook, simplesmente não existia em `/sys/class/drm/` — não era "detectado
e falhou", era como se a porta não existisse).

Resolvido tentando `zypper install` pacote a pacote (esbarrou em mais dois
conflitos de solver por causa de múltiplas revisões de build da mesma
versão `580.159.03` no repositório `NVIDIA:repo-non-free`), e só saiu limpo
removendo tudo relacionado e reinstalando do zero via dois pacotes "meta"
que existem exatamente pra isso: `nvidia-open-driver-G06-signed-kmp-meta`
(kernel module) + `nvidia-userspace-meta-G06` (userspace em sync). Com o
sistema limpo (sem nenhuma versão já fixada por um pacote individual), o
resolvedor de dependências escolheu um conjunto 100% consistente sozinho,
sem conflito.

**Implicação pra ISO NVIDIA**: a política de lockstep não pode travar só
kernel+kmp — precisa cobrir kmp+userspace+firmware como uma unidade só. Os
pacotes "meta" (`*-kmp-meta`/`nvidia-userspace-meta-G06`) parecem ser o
mecanismo certo pra isso (existem exatamente com esse propósito, "manter em
sync"), mas só foram testados aqui reinstalando do zero — não foi validado
se eles também resolvem uma atualização incremental sem conflito quando já
há um pacote individual desalinhado (foi exatamente esse caso que forçou a
remoção completa). Vale essa mesma cautela ao desenhar como o Vega
atualizaria o trio kernel+kmp+userspace numa máquina já instalada.

## Gate e evidência (não bloqueante para a ISO padrão)

Reaproveitar o formato de `docs/release-gate.md`/`hardware-matrix.md`, mas
como gate próprio e independente:
- boot da imagem, sessão live e instalação completam sem fallback;
- driver carrega, `nvidia-smi`/`glxinfo` confirmam renderização pela GPU
  NVIDIA, sessão GNOME (Wayland, se suportado pela combinação
  driver+kernel-default do Leap 16 alvo) funcional;
- comportamento de Secure Boot registrado explicitamente conforme a rota
  escolhida acima (ligado com módulo assinado, ligado com MOK enrolado, ou
  desligado por decisão documentada) — nunca "não testado";
- pelo menos uma entrada real de `lyra-hardware-matrix` com GPU NVIDIA
  dedicada, sem substituir a cobertura Intel/AMD obrigatória da ISO padrão
  (`docs/hardware-matrix.md:5-7`).

## Questões em aberto (bloqueiam início da implementação)

1. Rota de Secure Boot (seção acima) — decisão de segurança, não técnica.
2. Fonte/proveniência do pacote do driver: novo projeto OBS Lyra vs. repo
   oficial NVIDIA direto.
3. Laptops híbridos Optimus/PRIME entram no escopo do primeiro ciclo desta
   ISO, ou fica limitado a desktops com GPU NVIDIA dedicada única? A
   máquina física de teste do Rodrigo é justamente um híbrido
   Intel+NVIDIA — o driver+firmware corretos e em lockstep bastaram pra
   saída de vídeo cabeada na NVIDIA (HDMI, neste caso) funcionar, sem
   precisar de nenhum ajuste específico de PRIME/mux além disso. Não é
   validação completa do cenário híbrido (não cobre alternar GPU em uso,
   render offload, etc.), só evidência de que o caso básico (saída de
   vídeo fixa na dGPU) funciona com o driver certo.
4. Política de lockstep kernel+kmp **e kmp+userspace+firmware** (achado
   real, ver seção "Kernel e módulo em lockstep") em atualizações via
   Vega/`zypper dup` — os pacotes `*-kmp-meta`/`nvidia-userspace-meta-G06`
   parecem ser o mecanismo certo, mas só testados reinstalando do zero, não
   numa atualização incremental com pacotes já desalinhados.
5. Nome/branding público da variante (ex.: "Lyra OS NVIDIA Edition") e se ela
   compartilha `release.toml`/calendar version com a ISO padrão ou tem o
   próprio ciclo de release.

## Referências

- `PROMPT-LYRA-OS.md` — decisão de que a variante fica para o pós-release e
  de que a ISO padrão não instala driver NVIDIA automaticamente.
- `docs/image-builds.md:117-118` — limite já registrado: deliverable
  separado, sem flavor de imagem na OBS, não bloqueia a ISO padrão.
- `docs/hardware-matrix.md:5-7` — a pilha aberta NVIDIA não substitui nem
  depende desta ISO.
- `docs/installer-architecture.md` — caminho atual de GRUB/shim/Secure Boot
  que este documento propõe estender.
- `docs/release-gate.md` — formato de gate reaproveitado para a evidência
  não bloqueante desta variante.

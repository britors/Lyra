# Recuperação da estação de desenvolvimento

Este guia deve ser usado depois de instalar o Lyra OS em uma máquina limpa.
Ele restaura as ferramentas de desenvolvimento, mas deliberadamente não copia
senhas, tokens, cookies, chaves privadas ou arquivos de credenciais.

## Antes de formatar

Confirme estes itens enquanto a instalação antiga ainda existe:

- `git status --short --branch` está limpo e `main` está sincronizado com o
  GitHub;
- a ISO e os artefatos necessários já foram enviados ao SourceForge;
- arquivos pessoais fora do Git foram copiados para armazenamento seguro;
- nenhuma credencial existe apenas no chaveiro local;
- a partir da Beta 1, o backup offline da chave de release e o certificado de
  revogação foram testados conforme ADR 0005.

Os diretórios `kiwi/.kiwi`, `installer/target`, `/tmp` e os discos das VMs não
são fonte de verdade. Podem ser reconstruídos. Não adie a formatação apenas
para preservar caches.

## 1. Entrada mínima após instalar o sistema

Abra um terminal como o usuário administrativo criado pelo instalador. Não
entre como `root` e não execute o bootstrap inteiro com `sudo`.

```bash
sudo zypper --non-interactive refresh
sudo zypper --non-interactive install git curl ca-certificates
mkdir -p ~/Git
git clone https://github.com/britors/Lyra.git ~/Git/Lyra
cd ~/Git/Lyra
```

O clone HTTPS funciona antes da autenticação no GitHub e permite obter o
bootstrap sem depender de uma chave SSH antiga.

## 2. Restaurar as ferramentas

Primeiro visualize o que será alterado:

```bash
./scripts/bootstrap-development.sh --dry-run
```

Depois execute a instalação completa:

```bash
./scripts/bootstrap-development.sh
```

O script instala e verifica, entre outros:

- Git, Git LFS e GitHub CLI (`gh`);
- Codex CLI;
- `osc` e integração com o chaveiro do GNOME;
- Rust/rustup, Node.js, Go, Python e ferramentas de build RPM;
- KIWI, QEMU/KVM, OVMF, libvirt e ferramentas de validação da ISO.

Ao terminar, encerre a sessão e entre novamente. Isso ativa os grupos `kvm` e
`libvirt` adicionados durante o bootstrap.

## 3. Identidade Git e GitHub

Configure a identidade usada nos commits:

```bash
git config --global user.name "Rodrigo Brito"
git config --global user.email "SEU_EMAIL_DE_COMMIT"
```

Autentique o GitHub pelo navegador e configure o transporte Git:

```bash
gh auth login --hostname github.com --git-protocol ssh --web
gh auth setup-git
gh auth status
```

Não copie tokens para scripts ou para o repositório. Se o `gh` criar ou pedir
uma nova chave SSH, adicione somente a chave pública à conta GitHub.

Confira o remoto e a sincronização:

```bash
cd ~/Git/Lyra
git remote -v
git fetch --prune origin
git status --short --branch
```

## 4. Codex CLI

```bash
codex login
codex login status
```

Abra o Codex a partir do repositório para que o workspace correto seja usado:

```bash
cd ~/Git/Lyra
codex
```

As conversas locais e caches da instalação anterior não são fonte de verdade.
Decisões importantes devem estar em `docs/`, ADRs, issues ou commits.

## 5. Open Build Service

O bootstrap cria `~/.config/osc/oscrc` com o usuário OBS `rodrigosbrito` e
armazenamento de credenciais no chaveiro. Autentique novamente sem colocar a
senha na linha de comando:

```bash
osc config https://api.opensuse.org --change-password
osc my projects
./scripts/obs-release.py check --channel release
```

Nunca restaure um `oscrc` contendo senha em texto puro.

## 6. SourceForge

O usuário de publicação é `rodrigobritosoa`. O script fixa o host e o destino,
e o SSH solicita diretamente a senha ou passphrase quando necessário:

```bash
./scripts/upload-desktop-alpha3-sourceforge.sh --check-only
```

Não republique a Alpha 3 apenas para testar credenciais. Para um lançamento
novo, use o script correspondente à versão e confirme o diretório remoto antes
do envio.

## 7. Verificação da estação reconstruída

```bash
cd ~/Git/Lyra
python3 -m unittest discover -s tests -q
cargo test --manifest-path installer/Cargo.toml \
  -p lyra-installer-core --locked --offline
./scripts/release.py check
./scripts/image-build.py validate
gh auth status
osc my projects
codex login status
```

Confira a virtualização após abrir uma nova sessão:

```bash
test -r /dev/kvm && test -w /dev/kvm
qemu-system-x86_64 -display help | grep gtk
```

## 8. Retomada segura

Antes de editar ou publicar qualquer coisa:

```bash
git pull --ff-only
git status --short --branch
gh issue list --repo britors/Lyra --state open --limit 100
```

Fontes ficam no GitHub, RPMs no OBS e ISOs no SourceForge. Se algum estado
importante existir somente nesta máquina, registre-o no local correto antes de
continuar o ciclo de release.

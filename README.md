# Lyra OS

Lyra OS é uma distribuição Linux desktop baseada no openSUSE Leap 16,
voltada a uma experiência GNOME simples, estável e integrada ao ecossistema
Lyra. Este repositório contém a descrição KIWI usada para gerar a ISO live e
o instalador da edição **Odisseia Beta 1** para computadores x86_64.

> [!IMPORTANT]
> O projeto ainda está em desenvolvimento. A ISO não deve ser considerada uma
> versão final até que o ciclo completo de build, instalação e inicialização do
> sistema instalado seja validado novamente após as correções mais recentes.

## Principais características

- openSUSE Leap 16 com GNOME 48 ou superior;
- sessão live e instalação gráfica pelo Calamares;
- Btrfs com Snapper e snapshots automáticos durante operações do Zypper;
- recuperação por snapshots no menu do GRUB;
- inicialização UEFI e suporte ao Secure Boot com o shim do openSUSE;
- zram com compressão Zstandard, sem swapfile;
- Firefox, LibreOffice, GNOME Software, Flatpak e Flathub;
- Vega, Sheliak e Fina pré-instalados pelos repositórios OBS do Lyra;
- identidade visual Lyra Enterprise no desktop e no GRUB;
- `lyra-report` para diagnóstico local e sob demanda, sem telemetria ou envio
  automático de dados.

O sistema não habilita o Packman. Os repositórios oficiais do Leap têm
prioridade sobre os repositórios OBS do ecossistema Lyra no sistema instalado.

## Estado atual

A configuração da imagem, a integração do instalador e as validações locais do
artefato estão implementadas. Builds e testes em VM já identificaram e
orientaram correções no boot da imagem live, na autorização do Calamares e na
configuração do Snapper.

Ainda estão pendentes:

- repetir o teste completo de instalação e boot após as correções mais
  recentes, incluindo o caminho com Secure Boot;
- substituir as imagens e o slideshow genéricos do Calamares por arte própria
  do Lyra;
- publicar codecs multimídia no OBS do Lyra, sem recorrer ao Packman;
- automatizar o ciclo de CI e publicação da ISO.

Consulte a [documentação técnica do KIWI](kiwi/README.md) para conhecer as
decisões de implementação, limitações e verificações já realizadas.

## Preparando o ambiente

O ambiente de desenvolvimento suportado é o Lyra OS ou o openSUSE Leap 16.0.
Clone o repositório e execute o bootstrap como usuário comum:

```bash
git clone https://github.com/britors/Lyra.git
cd Lyra
./scripts/bootstrap-development.sh --dry-run
./scripts/bootstrap-development.sh
```

O modo `--dry-run` mostra as ações antes de modificar o sistema. O script pede
`sudo` apenas quando precisa instalar pacotes ou configurar virtualização; não
execute o próprio script com `sudo`.

As opções disponíveis podem ser consultadas com:

```bash
./scripts/bootstrap-development.sh --help
```

Veja o [guia de contribuição](CONTRIBUTING.md) para configuração de Git,
GitHub, OBS, Codex e dos demais projetos do ecossistema.

## Gerando e testando a ISO

O caminho recomendado compila a imagem, executa verificações no resultado,
cria um disco virtual novo e inicia a sessão live no QEMU/KVM:

```bash
./kiwi/test/build-and-run-vm.sh
```

Para testar com Secure Boot:

```bash
./kiwi/test/build-and-run-vm.sh --secure-boot
```

Depois de concluir a instalação e fechar a VM, inicialize somente o sistema
instalado, preservando o estado UEFI correspondente:

```bash
./kiwi/test/build-and-run-vm.sh --boot-disk --secure-boot
```

O helper espera KVM disponível para o usuário atual, uma sessão gráfica, 8 GiB
de memória para a VM e espaço para um disco virtual de 20 GiB. Os builds, ISOs,
discos e logs ficam em `kiwi/.kiwi/test-<uid>/` e não são versionados. Use
`--skip-build` para reiniciar a ISO existente sem recompilá-la.

Também é possível executar somente o build do KIWI:

```bash
sudo kiwi-ng system build \
  --description kiwi \
  --target-dir /tmp/lyra-os-build
```

O build precisa de acesso à rede para baixar pacotes e registrar o Flathub na
imagem.

## Estrutura do repositório

| Caminho | Conteúdo |
|---|---|
| [`kiwi/config.xml`](kiwi/config.xml) | definição da imagem, repositórios e pacotes |
| [`kiwi/config.sh`](kiwi/config.sh) | configuração executada dentro da imagem |
| [`kiwi/root/`](kiwi/root/) | arquivos sobrepostos na raiz da ISO |
| [`kiwi/test/build-and-run-vm.sh`](kiwi/test/build-and-run-vm.sh) | build, validações e execução no QEMU |
| [`PROMPT-LYRA-OS.md`](PROMPT-LYRA-OS.md) | especificação de produto da primeira versão |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | preparação da estação e fluxo de contribuição |

## Privacidade

O Lyra OS não implementa telemetria automática. A ferramenta `lyra-report` só
é executada por solicitação do usuário, cria um arquivo local com permissão
restrita e nunca envia o relatório. Como logs podem conter nomes, caminhos e
outros dados pessoais, o conteúdo deve ser revisado antes de ser compartilhado.

## Contribuindo

Antes de enviar uma mudança, confira o diff, mantenha credenciais fora do
repositório e valide o fluxo afetado. Instruções detalhadas estão em
[`CONTRIBUTING.md`](CONTRIBUTING.md).

## Licença

O código e a documentação próprios deste projeto são distribuídos sob a
[GNU General Public License versão 3](LICENSE) (GPL-3.0). Arquivos e recursos
originados de terceiros permanecem sob as licenças indicadas nos próprios
arquivos ou nos respectivos metadados.

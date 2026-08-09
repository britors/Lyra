# Imagem KIWI do Lyra OS

`config.xml` é a descrição canônica da ISO live/instalável da Beta 2. A
imagem usa openSUSE Leap 16, GNOME, Btrfs/Snapper e o Lyra Installer em
Rust/Tauri como único instalador.

## Instalador na sessão live

O RPM `lyra-installer` fornece:

- `/usr/bin/lyra-installer`, executado como `liveuser`;
- `/usr/libexec/lyra-installer-service`, iniciado por `pkexec` somente após
  a confirmação do plano destrutivo;
- desktop entry, ícone, policy e regra polkit.

O overlay também fixa `lyra-install-lock`, launcher e ícone, mantidos idênticos
às fontes do RPM por testes automatizados. Assim, uma versão publicada
anteriormente não quebra o autostart ou a identidade visual enquanto o novo
RPM ainda está sendo promovido.

O overlay `root/etc/xdg/autostart/lyra-installer-autostart.desktop` abre a
interface depois do login automático no GNOME. A interface inteira nunca roda
como root. O sistema instalado remove conta, autostart, binários e privilégios
exclusivos da sessão live antes do primeiro snapshot.

Não existe segundo instalador, launcher alternativo ou regra polkit de
fallback na Beta 2.

## Build e teste

Use o helper versionado:

```bash
./kiwi/test/build-and-run-vm.sh
```

Ele valida metadados, constrói a imagem, cria disco e estado UEFI descartáveis
e inicia a VM em QEMU/KVM. Cada chamada encerra a instância anterior criada
pelo helper e apaga seu disco/NVRAM. Para validar o sistema instalado, reinicie
o guest na mesma janela: a ISO só é priorizada no primeiro boot da execução.

O modo padrão é de desenvolvimento: compila o workspace `installer/` e fixa
seus binários na descrição KIWI temporária, com proveniência explícita dentro
da imagem. Para validar um candidato publicável, use
`--published-installer`; esse modo consome somente o RPM assinado do OBS.
Uma imagem marcada como `local-installer-build` não é artefato de release.

Consulte `docs/image-builds.md` para a fronteira
GitHub/OBS/SourceForge e `docs/installer-architecture.md` para o pipeline do
instalador.

Antes de publicar a Beta 2, o gate #11 deve comprovar instalação, primeiro
boot, UEFI, Secure Boot, Btrfs/Snapper, rollback, usuário/sudo e ausência de
artefatos da sessão live no target. A presença do instalador na ISO não
substitui esse teste destrutivo.

## Repositórios

Durante o build, os repositórios OBS Lyra, Vega e Fina usam prioridades 1, 2
e 3 para selecionar os pacotes revisados. O instalador rebaixa esses três
repositórios para prioridade 90 no target; os repositórios oficiais do Leap,
com prioridades 20 e 21, vencem futuras resoluções de nomes iguais. O gate
`scripts/obs-release.py validate` verifica os dois lados desse contrato.

O arquivo `config.xml` contém a lista única de pacotes. Não mantenha uma lista
paralela em scripts ou documentação.

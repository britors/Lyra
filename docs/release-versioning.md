# Versionamento e rastreabilidade de releases

O arquivo [`release.toml`](../release.toml) é a única fonte editável da
identidade de uma release do Lyra OS. Não altere versões diretamente no KIWI,
no Calamares, na interface do instalador ou no arquivo gerado
`kiwi/root/usr/lib/lyra-os/release`.

## Convenção

O Lyra usa uma versão de calendário `AAAA.MM` e acrescenta o estágio enquanto
a imagem ainda é uma pré-release:

| Estágio | `release.toml` | Versão, tag e exemplo de ISO |
|---|---|---|
| Beta | `stage = "beta"`, `iteration = 2` | `2026.08-beta2`, `v2026.08-beta2`, `lyra-os.x86_64-2026.08-beta2.iso` |
| RC | `stage = "rc"`, `iteration = 1` | `2026.08-rc1`, `v2026.08-rc1`, `lyra-os.x86_64-2026.08-rc1.iso` |
| Final | `stage = "release"`, `iteration = 0` | `2026.08`, `v2026.08`, `lyra-os.x86_64-2026.08.iso` |

Uma nova compilação da mesma release mantém a versão. O commit, a data, o
estado limpo ou modificado da árvore e o SHA-256 distinguem builds e ficam no
manifesto `*.iso.manifest.json` criado pelo helper de build.

## Preparação de uma versão

1. Edite apenas os campos em `release.toml`.
2. Renderize os consumidores versionados:

   ```bash
   ./scripts/release.py render
   ```

3. Revise as mudanças e execute as validações:

   ```bash
   ./scripts/release.py check
   python3 -m unittest discover -s tests -v
   ```

4. Faça o build pelo helper. Ele rejeita metadados divergentes, um nome de ISO
   inesperado e um `VERSION_ID` incorreto dentro da imagem:

   ```bash
   ./kiwi/test/build-and-run-vm.sh
   ```

5. Somente um commit limpo e aprovado deve originar uma imagem publicada.
   Crie a tag derivada de `release.toml` no commit exato e use a mesma versão
   no título das notas de release. O campo pode ser consultado sem duplicar a
   regra:

   ```bash
   ./scripts/release.py field tag
   ./scripts/release.py field iso_filename
   ```

As notas devem registrar o nome da ISO, o SHA-256 e os campos `built_at` e
`source.commit` do manifesto. Uma árvore marcada como `source.dirty: true` é
adequada para desenvolvimento local, mas não para publicação.

## Campos sincronizados

O renderizador mantém alinhados:

- `<version>`, descrição e volume ID do KIWI;
- nome produzido para a ISO;
- `PRETTY_NAME`, `VERSION_ID`, `BUILD_ID`, `IMAGE_ID` e `IMAGE_VERSION` em
  `/etc/os-release`;
- strings de versão do Calamares e da interface do instalador;
- identificação corrente nos READMEs.

O workflow de CI executa o modo `check` e os testes. Assim, editar um arquivo
gerado sem alterar o manifesto, ou esquecer de renderizar uma mudança de
release, torna o job vermelho.

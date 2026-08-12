# Versionamento e rastreabilidade de releases

O arquivo [`release.toml`](../release.toml) é a única fonte editável da
identidade de uma release do Lyra OS. Não altere versões diretamente no KIWI,
na interface do instalador ou no arquivo gerado
`kiwi/root/usr/lib/lyra-os/release`.

## Convenção

O Lyra usa uma versão de calendário `AAAA.MM` e acrescenta o estágio enquanto
a imagem ainda é uma pré-release:

| Estágio | `release.toml` | Versão, tag e exemplo de ISO |
|---|---|---|
| Alpha | `stage = "alpha"`, `iteration = N` | `2026.08-alphaN`, `v2026.08-alphaN`, `lyra-os.x86_64-2026.08-alphaN.iso` |
| Beta | `stage = "beta"`, `iteration = N` | `2026.08-betaN`, `v2026.08-betaN`, `lyra-os.x86_64-2026.08-betaN.iso` |
| RC | `stage = "rc"`, `iteration = N` | `2026.08-rcN`, `v2026.08-rcN`, `lyra-os.x86_64-2026.08-rcN.iso` |
| Final | `stage = "release"`, `iteration = 0` | `2026.08`, `v2026.08`, `lyra-os.x86_64-2026.08.iso` |

O build atual é `alpha3`: evolução da Alpha 2 com as correções encontradas na
validação do instalador, mantendo a classificação Alpha porque ainda há
correções de funcionalidade central do instalador em andamento
(partição, sudo, permissões pkexec), não apenas estabilização. A tag já
publicada `v2026.08-beta2-stable-20260809` permanece como registro histórico
e não é reescrita; o próximo ciclo de beta deste produto recomeça em `beta1`.

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

A decisão final segue a checklist versionada em
[`release-gate.md`](release-gate.md). O manifesto de evidências rejeita árvore
suja, resultado vermelho e qualquer evidência obrigatória ausente.

## Cronograma do ciclo Lyra OS 1.0

O número de iterações por estágio é um teto, não uma meta fixa: a promoção
de estágio é liberada por critério de saída (nenhum item P0/P1 aberto no
[`release-gate.md`](release-gate.md) para o estágio corrente), não apenas
pela data. As datas abaixo assumem o cenário em que todo o teto é usado; se
um estágio fechar mais cedo, a promoção acontece mais cedo.

| Estágio | Cadência | Datas |
|---|---|---|
| alpha3 | 3 semanas | 11/ago/2026 → 01/set/2026 |
| alpha4 | 3 semanas | 01/set/2026 → 22/set/2026 |
| alpha5 | 3 semanas | 22/set/2026 → 13/out/2026 |
| beta1 | 4 semanas | 13/out/2026 → 10/nov/2026 |
| beta2 | 4 semanas | 10/nov/2026 → 08/dez/2026 |
| beta3 | 4 semanas | 08/dez/2026 → 05/jan/2027 |
| rc1 | 2 semanas | 05/jan/2027 → 19/jan/2027 |
| rc2 | 2 semanas | 19/jan/2027 → 02/fev/2027 |
| final (buffer) | 2 semanas | 02/fev/2027 → **~16/fev/2027** |

Se o estágio alpha fechar em `alpha4` (sem pendência P1), o ciclo inteiro
antecipa e a final sai em torno de **~26/jan/2027**. O alvo interno é
janeiro; fevereiro é a folga não comprometida, não parte do prazo prometido.
A final deste ciclo é publicada como **Lyra OS 1.0**.

## Lyra OS 1.1 (rebase para openSUSE Leap 16.1)

Início em março/2027, ~1 mês após a final do 1.0. A base muda de Leap 16.0
para Leap 16.1 (GA em 03/nov/2026), o que exige revalidar disponibilidade de
pacotes, ABI, shim de Secure Boot e matriz de hardware contra o novo
repositório — não é um bump cosmético de número. O funil é mais enxuto que o
do 1.0 porque o tooling de release e o gate já existem; só a base precisa de
requalificação:

| Estágio | Cadência | Datas |
|---|---|---|
| alpha1 | 3 semanas | 01/mar/2027 → 22/mar/2027 |
| alpha2 | 3 semanas | 22/mar/2027 → 12/abr/2027 |
| alpha3 | 3 semanas | 12/abr/2027 → 03/mai/2027 |
| beta1 | 4 semanas | 03/mai/2027 → 31/mai/2027 |
| beta2 | 4 semanas | 31/mai/2027 → 28/jun/2027 |
| rc1 | 2 semanas | 28/jun/2027 → 12/jul/2027 |
| rc2 | 2 semanas | 12/jul/2027 → 26/jul/2027 |
| final (buffer) | 2 semanas | 26/jul/2027 → **~09/ago/2027** |

"1.0" e "1.1" são nomes de produto para os ciclos de release, complementares
ao `calendar_version` (`AAAA.MM`) que continua sendo o campo mecânico em
`release.toml` — não existe hoje um campo separado de versão semântica major.minor
no schema; se isso precisar virar um campo formal (por exemplo para
exibição em release notes), é uma decisão em aberto, não assumida aqui.

## Campos sincronizados

O renderizador mantém alinhados:

- `<version>`, descrição e volume ID do KIWI;
- nome produzido para a ISO;
- `PRETTY_NAME`, `VERSION_ID`, `BUILD_ID`, `IMAGE_ID` e `IMAGE_VERSION` em
  `/etc/os-release`;
- strings de versão da interface do instalador;
- identificação corrente nos READMEs.

O workflow de CI executa o modo `check` e os testes. Assim, editar um arquivo
gerado sem alterar o manifesto, ou esquecer de renderizar uma mudança de
release, torna o job vermelho.

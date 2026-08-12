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

O build atual é `alpha4`: ciclo de internacionalização do instalador,
primeira onda de pacotes próprios e fluxo opcional NVIDIA pelo Vega,
mantendo a classificação Alpha porque ainda há funcionalidades planejadas
em implementação, não apenas estabilização. A tag já
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

| Estágio | Cadência | Datas | Política |
|---|---|---|---|
| alpha3 | 3 semanas | 11/ago/2026 → 01/set/2026 | Fechar o instalador suportado e sua publicação. |
| alpha4 | 3 semanas | 01/set/2026 → 22/set/2026 | Implementar i18n base, instalador bilíngue, primeira onda de pacotes e instalação NVIDIA via Vega. |
| alpha5 | 3 semanas | 22/set/2026 → 13/out/2026 | Concluir i18n de todos os pacotes, integração e qualquer feature restante. |
| alpha6, se necessária | até 3 semanas | após alpha5 | Fechar gates ainda vermelhos sem reduzir escopo ou promover P0/P1 para Beta. |
| beta1 | 4 semanas | após a última Alpha | **Feature freeze:** somente bugs, regressões, segurança, desempenho e correções de traduções existentes. |
| beta2 | 4 semanas | 10/nov/2026 → 08/dez/2026 | Estabilidade e atualização; nenhuma feature nova. |
| beta3 | 4 semanas | 08/dez/2026 → 05/jan/2027 | QA linguístico e correções finais; nenhuma infraestrutura ou novo componente traduzido. |
| rc1 | 2 semanas | 05/jan/2027 → 19/jan/2027 | Somente bloqueadores P0/P1 e repetição do gate. |
| rc2 | 2 semanas | 19/jan/2027 → 02/fev/2027 | Somente bloqueadores P0/P1 e preparação da publicação. |
| final (buffer) | 2 semanas | 02/fev/2027 → **~16/fev/2027** | Publicação e verificação dos artefatos; nenhuma mudança funcional. |

### Desktop Alpha 4 — 01/09 a 22/09

O Lyra Installer da 1.0 oferece **inglês dos Estados Unidos (`en-US`)**,
**português do Brasil (`pt-BR`)**, **espanhol da Espanha (`es-ES`)** e
**chinês simplificado (`zh-CN`)**, com `en-US` como padrão e fallback. O gate
integral dos demais pacotes próprios permanece em `en-US`/`pt-BR`; idiomas
adicionais ficam para a versão 1.1.

- **01–07/set:** inventariar strings de todos os pacotes próprios; definir o
  contrato de catálogos, pluralização, seleção de locale e fallback; adicionar
  extração/lint no CI e marcar explicitamente pacotes sem interface como N/A.
- **08–14/set:** internacionalizar integralmente o Lyra Installer, incluindo
  HTML/JavaScript, validações, erros Tauri, eventos do serviço privilegiado e
  evidências; a escolha de idioma deve atualizar a interface sem reiniciar.
- **15–22/set:** internacionalizar a primeira onda instalada por padrão
  (`Vega`, `Fina` e `Sheliak`) e entregar no Vega a instalação opcional
  pós-instalação do driver NVIDIA para o cenário suportado.

O driver não entra no Lyra Installer nem na ISO padrão. O fluxo do Vega exige
detecção conservadora, confirmação explícita, Secure Boot verificado, snapshot
Snapper, pacotes meta em lockstep, `dracut`, reinício e rollback. Alpha 4 só
fecha com o instalador funcionando nos quatro idiomas, a primeira onda de
pacotes funcionando em `pt-BR` e `en-US`, e o
fluxo NVIDIA validado no hardware G06 disponível.

### Desktop Alpha 5 — 22/09 a 13/10

- **22–28/set:** internacionalizar `Beam`, `Chord`, `Sulafat`, `Aladfar`,
  `Prosa`, `Calco`, `postgres-draco`, `vega-cli`, `vega-web` e `vegad`; cada
  pacote sem texto voltado ao usuário deve registrar N/A em vez de desaparecer
  do inventário.
- **29/set–05/out:** integrar os RPMs traduzidos na imagem, validar troca de
  idioma e fallback, concluir compatibilidade/recuperação do fluxo NVIDIA e
  eliminar strings literais fora dos catálogos permitidos.
- **06–13/out:** nenhuma feature nova. Corrigir somente defeitos encontrados
  na instalação, atualização, tradução e hardware; executar o gate completo e
  auditar que todas as features planejadas para 1.0 estão implementadas ou
  formalmente removidas do escopo.

**13/10/2026 é meta, não promoção automática.** A Beta 1 inicia o congelamento
funcional somente após a última Alpha fechar os gates. Uma
mudança depois desse ponto só pode corrigir bug, regressão, vulnerabilidade,
desempenho ou tradução já existente. Novo componente, novo fluxo, novo idioma
ou nova infraestrutura de i18n volta para o próximo ciclo, salvo P0/P1 com
decisão formal registrada.

Alpha 5 é obrigatória para fechar internacionalização e features. Se ela não
for suficiente, a Alpha 6 é preferível a uma Beta incompleta. Fevereiro
continua sendo a folga máxima do cronograma, não motivo para reduzir os gates.
A final deste ciclo é publicada como **Lyra OS 1.0**.

## Lyra OS Server 1.0

O Server possui ciclo independente, mas usa os mesmos critérios de promoção e
a mesma cadência do Desktop: Alphas de até 3 semanas, Betas de até 4 semanas,
RCs de até 2 semanas e buffer final de 2 semanas. Uma etapa fecha quando seus
gates ficam verdes; as datas são teto, não motivo para promover uma imagem com
P0/P1 aberto.

| Estágio | Cadência | Datas | Objetivo de saída |
|---|---|---|---|
| alpha1 | 3 semanas | 11/ago/2026 → 01/set/2026 | Reconfirmar instalação completa após os últimos ajustes da TUI e produzir o primeiro candidato rastreável. |
| alpha2 | 3 semanas | 01/set/2026 → 22/set/2026 | Fechar boot UEFI/Secure Boot, primeiro boot, DHCP, SSH, firewall, `vegad` e `vega-web` com evidência automatizada. |
| alpha3, se necessária | 3 semanas | 22/set/2026 → 13/out/2026 | Resolver P1 remanescente e ampliar a matriz de hardware; não adicionar novo escopo funcional. |
| beta1 | 4 semanas | 13/out/2026 → 10/nov/2026 | Congelamento funcional e validação do fluxo suportado em disco inteiro/ext4. |
| beta2 | 4 semanas | 10/nov/2026 → 08/dez/2026 | Estabilidade, atualização dos pacotes, rede e administração remota em execuções repetidas. |
| beta3 | 4 semanas | 08/dez/2026 → 05/jan/2027 | Internacionalização dos componentes próprios aplicáveis ao Server e fechamento da documentação operacional. |
| rc1 | 2 semanas | 05/jan/2027 → 19/jan/2027 | Candidato completo, assinado e exercitado em VM e hardware físico, sem P0/P1. |
| rc2 | 2 semanas | 19/jan/2027 → 02/fev/2027 | Somente correções bloqueantes e repetição integral do gate. |
| final (buffer) | 2 semanas | 02/fev/2027 → **~16/fev/2027** | Publicação da Lyra OS Server 1.0 e verificação dos artefatos baixados. |

Se o Server fechar a fase Alpha na `alpha2`, sem P0/P1 e com todas as
evidências obrigatórias, as etapas seguintes podem ser antecipadas e a final
fica em torno de **~26/jan/2027**. O Server não precisa esperar o Desktop nem
ser publicado no mesmo dia; cada edição só avança com o próprio gate verde.

### Estado na entrada da Alpha 1

O fluxo boot live → TUI → disco inteiro/GPT/ESP/ext4 → chroot → shim/GRUB →
primeiro boot já completou em VM, com DHCP, SSH, `vegad` e `vega-web` ativos.
Os testes locais de shell, comportamento da TUI, segurança de senha/sudo e
identidade do overlay estão verdes. Permanecem como bloqueadores para sair da
Alpha 1:

- repetir o fluxo ponta a ponta depois das correções finais do gauge e do
  nível de log do console;
- validar Secure Boot e os argumentos reais de `shim-install` no candidato;
- gerar ISO, checksum, assinatura, inventário, SBOMs e manifesto de evidência
  a partir de uma árvore limpa;
- executar `lyra-system-smoke` para sessão live e primeiro boot;
- registrar a matriz de hardware, incluindo ao menos o risco explícito da
  cobertura física disponível.

## Lyra OS 1.1 (rebase para openSUSE Leap 16.1)

Início em março/2027, ~1 mês após a final do 1.0. A base muda de Leap 16.0
para Leap 16.1 (GA em 03/nov/2026), o que exige revalidar disponibilidade de
pacotes, ABI, shim de Secure Boot e matriz de hardware contra o novo
repositório — não é um bump cosmético de número. O funil é mais enxuto que o
do 1.0 porque o tooling de release e o gate já existem; só a base precisa de
requalificação:

Este ciclo também abre a expansão para idiomas além de `en-US` e `pt-BR`.
Cada idioma novo precisa de catálogo completo dos componentes em escopo,
revisão humana, fallback para `en-US` e gate linguístico antes de aparecer no
seletor do Lyra Installer.

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

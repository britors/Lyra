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

## Contrato de maturidade

As datas do cronograma são limites de planejamento, não autorização para
promover um produto que ainda não atingiu o estágio seguinte. Se necessário,
o lançamento atrasa. O objetivo não é alegar perfeição, mas entregar uma
distribuição previsível e “chata de tão confiável”: ela deve poder ser usada
diariamente por um período prolongado sem travar, degradar, exigir manutenção
recorrente ou interromper o trabalho do usuário.

| Estágio | Estado esperado | Mudanças permitidas |
|---|---|---|
| Alpha | Produto em construção e qualificação | Funcionalidades planejadas, integração e correções, sempre com estabilidade em primeiro lugar. |
| Beta | Escopo completo e funcionalmente congelado | Correções de bugs, regressões, segurança, desempenho, acessibilidade e traduções existentes. |
| RC | Produto já estável; candidato completo sob verificação final | Nenhuma mudança rotineira. Defeito não trivial interrompe a promoção, devolve o produto à estabilização e exige uma nova RC. |
| Estável | Conteúdo funcional publicado e congelado | Somente correções de segurança. Demais correções e mudanças seguem para o próximo ciclo completo. |

A promoção para RC afirma que os gates de estabilidade já estão verdes; a RC
não é uma Beta com outro nome. A promoção para estável confirma o mesmo
conteúdo após a última verificação de imagem, assinatura, instalação,
atualização, recuperação e uso real. Ausência de P0/P1 é requisito mínimo, não
evidência suficiente por si só.

O build atual é `alpha6`: ciclo de conclusão do Lyra Upgrade, do fluxo de
atualizações e do backend de controle parental, mantendo a classificação Alpha
porque ainda há funcionalidades planejadas em implementação, não apenas
estabilização. A tag já
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
| alpha3 | concluída | 11/ago/2026 | Fechar o instalador suportado e sua publicação. |
| alpha4 | snapshot antecipado | 14/ago/2026 | Publicar i18n base, instalador em três idiomas e primeira onda de pacotes. |
| alpha5 | 2 semanas | 14/ago/2026 → 28/ago/2026 | Corrigir bloqueadores herdados; fechar i18n, NVIDIA pelo Vega e contratos do Lyra Upgrade. |
| alpha6 | 2 semanas | 28/ago/2026 → 11/set/2026 | Concluir core, serviço, interface e fluxos de update/upgrade; entregar backend parental. |
| alpha7 | 2 semanas | 11/set/2026 → 25/set/2026 | Integrar controles parentais no Vega e executar a trilha de compatibilidade. |
| alpha8 | 2 semanas e 4 dias | 25/set/2026 → 13/out/2026 | Fechar upgrade e gate até 06/out; estabilizar exclusivamente de 06–13/out. |
| beta1 | 4 semanas | 13/out/2026 → 10/nov/2026 | **Feature freeze:** somente bugs, regressões, segurança, desempenho e correções de traduções existentes. |
| beta2 | 4 semanas | 10/nov/2026 → 08/dez/2026 | Estabilidade e atualização; nenhuma feature nova. |
| beta3 | 4 semanas | 08/dez/2026 → 05/jan/2027 | QA linguístico e correções finais; nenhuma infraestrutura ou novo componente traduzido. |
| rc1 | 2 semanas | 05/jan/2027 → 19/jan/2027 | Somente bloqueadores P0/P1 e repetição do gate. |
| rc2 | 2 semanas | 19/jan/2027 → 02/fev/2027 | Somente bloqueadores P0/P1 e preparação da publicação. |
| final (buffer) | 2 semanas | 02/fev/2027 → **~16/fev/2027** | Publicação e verificação dos artefatos; nenhuma mudança funcional. |

### Desktop Alpha 4 — publicação em 14/08

O Lyra Installer da 1.0 oferece somente **inglês dos Estados Unidos
(`en-US`)**, **português do Brasil (`pt-BR`)** e **espanhol da Espanha
(`es-ES`)**, com `en-US` como padrão e fallback. O gate integral mínimo dos
demais pacotes próprios permanece em `en-US`/`pt-BR`; outros idiomas ficam
para um ciclo futuro.

A Alpha 4 registra o ponto alcançado com a infraestrutura de catálogos e o
Lyra Installer em três idiomas. Depois de sua publicação, todos os projetos e
RPMs foram concluídos e testados em `en-US`, `pt-BR` e `es-ES`; o fluxo NVIDIA
também foi concluído e validado antecipadamente na Alpha 5.

O driver não entra no Lyra Installer nem na ISO padrão. O fluxo validado do Vega exige
detecção conservadora, confirmação explícita, Secure Boot verificado, snapshot
Snapper, pacotes meta em lockstep, `dracut`, reinício e rollback. O fluxo só
foi declarado suportado depois da validação no hardware G06 disponível.

### Desktop Alpha 5 — 14/08 a 28/08

- corrigir os bloqueadores herdados do instalador e do pipeline de release
  antes de ampliar o escopo (#90, #91 e #92).
- aprovar arquitetura, modelo de ameaças, protocolos e máquina de estados do
  Lyra Upgrade (#81), pois esse contrato bloqueia as demais implementações.
- concluir o enquadramento jurídico do ECA Digital (#106), auditar a referência
  do BigLinux (#112), qualificar a base upstream (#110), especificar a
  experiência no Vega (#108) e aprovar a arquitetura e os contratos (#111).
- estabelecer a baseline e a cadência de acompanhamento regulatório LTS
  (#113), sem autorizar ampliação silenciosa após o congelamento funcional.
- concluído antecipadamente: todos os projetos e RPMs nos três idiomas (#78),
  NVIDIA pelo Vega e remoção da ISO dedicada (#77) e qualificação na imagem
  (#79).

### Desktop Alpha 6 — 28/08 a 11/09

- criar o programa Lyra Upgrade em Rust e estabilizar seu protocolo (#103).
- implementar o core não privilegiado, preflight, plano reproduzível e estado
  durável do Lyra Upgrade (#86).
- implementar o serviço privilegiado e a atualização segura dentro da mesma
  release (#83), com testes de falha antes da integração.
- implementar o upgrade entre releases com manifesto assinado, simulação
  reproduzível e aplicação offline (#82).
- criar a interface acessível e os três catálogos do Lyra Upgrade, incluindo
  retomada da UI e apresentação de falhas (#88).
- implementar o serviço autenticado, versionado e persistente de políticas de
  controle parental (#114), independente do processo gráfico do Vega.

### Desktop Alpha 7 — 11/09 a 25/09

- integrar no Vega a configuração parental e a autorização de aplicativos
  sobre o backend já qualificado (#109).
- concluído antecipadamente: verificação pós-boot, recuperação e rollback
  determinístico pelo snapshot registrado na operação (#85).

### Desktop Alpha 8 — 25/09 a 13/10

- **25/set–06/out:** automatizar update, upgrade, reboot, Secure Boot e rollback
  no release gate, usando RPMs reais do candidato (#87).
- automatizar o gate de conformidade, privacidade e regressão do ECA Digital,
  incluindo testes de evasão e evidências ligadas ao release (#107).
- **06–13/out:** nenhuma feature nova. Corrigir defeitos, repetir o gate
  completo e auditar que toda feature 1.0 foi implementada ou formalmente
  removida do escopo (#80).

**13/10/2026 é meta, não promoção automática.** A Beta 1 inicia o congelamento
funcional somente após a última Alpha fechar os gates. Uma
mudança depois desse ponto só pode corrigir bug, regressão, vulnerabilidade,
desempenho ou tradução já existente. Novo componente, novo fluxo, novo idioma
ou nova infraestrutura de i18n volta para o próximo ciclo, salvo P0/P1 com
decisão formal registrada.

Alpha 5, Alpha 6, Alpha 7 e Alpha 8 são obrigatórias. Toda funcionalidade deve
estar encerrada até 25/09; a semana final da Alpha 8 é reservada exclusivamente
para estabilização. O novo fracionamento não
autoriza reduzir os gates para cumprir a data. Fevereiro continua sendo a
folga máxima do cronograma, não motivo para promover uma Beta incompleta.
A final deste ciclo é publicada como **Lyra OS 1.0**.

## Lyra OS Server 1.0 “Delos”

**Delos** é o codinome de produto deste ciclo do Server. Ele não é acrescentado
ao schema mecânico de `release-server.toml`, aos nomes de pacote nem ao volume
da imagem. O Server possui ciclo independente, mas usa os mesmos critérios de promoção e
a mesma cadência do Desktop: Alphas de até 3 semanas, Betas de até 4 semanas,
RCs de até 2 semanas e buffer final de 2 semanas. Uma etapa fecha quando seus
gates ficam verdes; as datas são teto, não motivo para promover uma imagem com
P0/P1 aberto.

| Estágio | Cadência | Datas | Objetivo de saída |
|---|---|---|---|
| alpha1 | 3 semanas | 11/ago/2026 → 01/set/2026 | Reconfirmar instalação completa após os últimos ajustes da TUI e produzir o primeiro candidato rastreável. |
| alpha2 | 3 semanas | 01/set/2026 → 22/set/2026 | Consolidar a integração do fluxo Server e preparar as correções e evidências do gate seguinte. |
| alpha3 | cancelada | — | Etapa absorvida pela Beta 1 por decisão do mantenedor em 15/08/2026. |
| beta1 | em andamento | desde 15/ago/2026 | Congelamento funcional, correção dos bloqueadores e validação do fluxo suportado em disco inteiro/ext4. |
| beta2 | 4 semanas | 10/nov/2026 → 08/dez/2026 | Estabilidade, atualização dos pacotes, rede e administração remota em execuções repetidas. |
| beta3 | 4 semanas | 08/dez/2026 → 05/jan/2027 | Internacionalização dos componentes próprios aplicáveis ao Server e fechamento da documentação operacional. |
| rc1 | 2 semanas | 05/jan/2027 → 19/jan/2027 | Candidato completo, assinado e exercitado em VM e hardware físico, sem P0/P1. |
| rc2 | 2 semanas | 19/jan/2027 → 02/fev/2027 | Somente correções bloqueantes e repetição integral do gate. |
| final (buffer) | 2 semanas | 02/fev/2027 → **~16/fev/2027** | Publicação da Lyra OS Server 1.0 “Delos” e verificação dos artefatos baixados. |

O mantenedor encerrou o desenvolvimento funcional e iniciou a Beta 1 em
15/08/2026. O conteúdo antes atribuído à Alpha 3 ficou restrito a correções
bloqueantes, estabilização e evidências dentro da Beta 1. O Server
não precisa esperar o Desktop nem ser publicado no mesmo dia; cada edição só
avança com o próprio gate verde. Mantida essa antecipação nas etapas seguintes,
o alvo antecipado da final permanece em **~26/jan/2027**; o buffer integral
continua até aproximadamente 16/02/2027.

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

## Lyra OS Server 1.1 “Tebas”

O ciclo Server 1.1 usa o codinome de produto **Tebas** e faz o rebase para
openSUSE Leap 16.1. O codinome não altera o schema mecânico de
`release-server.toml`, os nomes de pacote ou o volume da imagem. O Server
mantém promoção e gate independentes do Desktop.

| Estágio | Cadência | Datas | Objetivo de saída |
|---|---|---|---|
| alpha1 | 3 semanas | 01/mar/2027 → 22/mar/2027 | Requalificar build, instalação e primeiro boot sobre Leap 16.1. |
| alpha2 | 3 semanas | 22/mar/2027 → 12/abr/2027 | Fechar Secure Boot, rede, firewall e administração remota na nova base. |
| alpha3 | 3 semanas | 12/abr/2027 → 03/mai/2027 | Resolver bloqueadores e completar a matriz de hardware sem ampliar escopo. |
| beta1 | 4 semanas | 03/mai/2027 → 31/mai/2027 | Congelamento funcional e validação repetida do fluxo suportado. |
| beta2 | 4 semanas | 31/mai/2027 → 28/jun/2027 | Estabilidade, atualizações, rede e administração remota. |
| beta3 | 4 semanas | 28/jun/2027 → 26/jul/2027 | QA linguístico, documentação operacional e correções finais. |
| rc1 | 2 semanas | 26/jul/2027 → 09/ago/2027 | Candidato completo, assinado e exercitado em VM e hardware. |
| rc2 | 2 semanas | 09/ago/2027 → 23/ago/2027 | Somente bloqueadores P0/P1 e repetição integral do gate. |
| final estável (buffer) | 2 semanas | 23/ago/2027 → **~06/set/2027** | Publicação do Lyra OS Server 1.1 “Tebas” e verificação dos artefatos. |

## Lyra OS 1.1 “Ilíada” (rebase para openSUSE Leap 16.1)

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
| alpha1 | 2 semanas | 01/mar/2027 → 15/mar/2027 |
| alpha2 | 2 semanas | 15/mar/2027 → 29/mar/2027 |
| alpha3 | 2 semanas | 29/mar/2027 → 12/abr/2027 |
| alpha4 | 2 semanas | 12/abr/2027 → 26/abr/2027 |
| alpha5 | 2 semanas | 26/abr/2027 → 10/mai/2027 |
| alpha6 | 2 semanas | 10/mai/2027 → 24/mai/2027 |
| alpha7 | 2 semanas | 24/mai/2027 → 07/jun/2027 |
| alpha8 | 2 semanas | 07/jun/2027 → 21/jun/2027 |
| beta1 | 4 semanas | 21/jun/2027 → 19/jul/2027 |
| beta2 | 4 semanas | 19/jul/2027 → 16/ago/2027 |
| beta3 | 4 semanas | 16/ago/2027 → 13/set/2027 |
| rc1 | 2 semanas | 13/set/2027 → 27/set/2027 |
| rc2 | 2 semanas | 27/set/2027 → 11/out/2027 |
| final estável (buffer) | 2 semanas | 11/out/2027 → **~25/out/2027** |

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

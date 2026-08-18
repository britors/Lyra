# Auditoria técnica de `big-parental-controls`

Status: auditoria de referência para #112 — **não aprova reutilização**  
Repositório: `biglinux/big-parental-controls`  
Revisão auditada: `39cd6d272954da05d16d35f70292766d871e8116`  
Data: 18/08/2026

## Conclusão executiva

O projeto demonstra integração útil entre AccountsService, malcontent, polkit,
ACL, PAM, systemd e nftables. Entretanto, não pode ser importado, empacotado ou
usado como backend do Lyra no estado auditado. Foram encontrados vazamento de
dados entre usuários, defaults que enfraquecem silenciosamente a proteção,
persistência permissiva/não robusta, helper privilegiado amplo e dependências
específicas de Arch/BigLinux.

O Lyra pode aproveitar ideias e encaminhar correções upstream. Não deve copiar
o helper shell, o daemon ou declarar equivalência jurídica.

## Método

- leitura do README, código Rust/Python/shell, unidades, políticas D-Bus e
  polkit, empacotamento e testes;
- comparação entre comportamento do código e alegações públicas;
- análise estática das fronteiras de privilégio, persistência, autorização,
  falha, atualização e evasão;
- nenhum teste foi executado como root e nenhuma política foi aplicada ao host.

## Achados

### Críticos

#### BPC-01 — dados etários e histórico legíveis por qualquer usuário local

A política do system bus permite no contexto padrão:

- `GetAgeGroup(uid)` para UID arbitrário;
- `GetMonitoredUsers`;
- `GetAppUsage(username, days)`;
- `GetDailyTotals`, `GetHourlyDistribution` e `GetRecentSessions`.

Os métodos de histórico não vinculam o alvo ao UID do chamador. Um processo
local não privilegiado pode enumerar supervisionados, consultar faixa e obter
nomes de processos e horários de outro usuário. Isso contraria minimização e o
critério da #114 de impedir leitura por chamadores não autorizados.

**Decisão Lyra:** não reutilizar a API. Exigir autorização por método, vínculo
entre chamador/conta e respostas por finalidade; sinal etário não será uma
consulta geral por UID.

#### BPC-02 — ausência ou corrupção do perfil resulta em `18+`

`get_stored_age_range()` devolve `18+` quando o arquivo não existe, o JSON é
inválido, o usuário não está presente ou o valor não é reconhecido. Esse
fail-open transforma perda/corrupção de estado em adulto e pode liberar acesso.

Outros loaders também convertem falha/corrupção em configuração vazia, inclusive
usuários monitorados e limites. A proteção pode desaparecer silenciosamente
após escrita parcial ou defeito de atualização.

**Decisão Lyra:** schema/versionamento explícitos, escrita atômica sincronizada,
backup/rollback e estado `Unknown/Blocked` em ambiguidade; nunca inferir adulto.

#### BPC-03 — caminho de senha controlado pelo chamador é aberto e removido como root

O comando `create-full USERNAME FULLNAME PWFILE` do helper aceita caminho
arbitrário, verifica apenas `-f`, lê com `cat` e executa `rm -f`. Não comprova
dono, modo, diretório, link simbólico, inode ou vínculo com `PKEXEC_UID`.

Embora a UI crie um arquivo temporário `0600`, a fronteira privilegiada aceita
invocação direta após autenticação. Isso cria uma primitiva root de leitura e
remoção de arquivo e uma condição de troca entre validação e uso.

**Decisão Lyra:** não importar o helper. Segredo somente por descritor/pipe com
credenciais verificadas, sem caminho fornecido ao processo root.

### Altos

#### BPC-04 — helper monolítico e parâmetros insuficientemente tipados

Um único executável autorizado edita contas, senhas, grupos, ACLs, homes,
desktop entries, mounts, `/tmp`, PAM, systemd, JSON, nftables e histórico. A API
é uma lista de strings e CSV, com vários caminhos/JSON fornecidos pelo chamador.
Esse desenho amplia blast radius, dificulta autorização por capacidade e torna
rollback transacional impraticável.

Há ainda nomes que permitem hífen inicial e chamadas administrativas sem `--`,
além de estados regravados por redirecionamento comum. Mesmo onde o shell usa
arrays/aspas, a superfície total é incompatível com a API mínima exigida.

#### BPC-05 — estado sensível publicado como `0644`

Perfis etários, ACLs, limites e configurações DNS recebem modo `0644` em vários
fluxos. O `atomic_write()` do daemon usa `fs::write()` em nome previsível
`*.tmp`, não usa `O_NOFOLLOW`, `create_new`, fsync ou validação de dono/modo.
Renomear reduz truncamento, mas não fornece a durabilidade ou proteção esperada.

#### BPC-06 — autorização administrativa inconsistente

Parte das mutações usa pkexec; `EnableUser/DisableUser` depende apenas da
política D-Bus para grupo `wheel`, sem polkit por chamada. Os métodos aceitam
`username` e `uid` separadamente e não comprovam correspondência. Isso aumenta
o risco de estados incoerentes e torna difícil auditar qual responsável
autorizou cada mudança.

#### BPC-07 — ACL e DNS não constituem enforcement suficiente

ACL por caminho não cobre cópias, interpretadores, AppImage, binários em outros
prefixos, containers, chamadas indiretas nem atualização que substitua inode.
O hook de reaplicação reduz uma parte do problema, mas é específico do pacman.

O redirecionamento nftables alcança DNS clássico na porta 53, não DoH/DoT, VPN,
proxy, namespace/container ou resolução embutida. O próprio conjunto não deve
ser tratado como filtro completo de conteúdo.

### Médios

#### BPC-08 — coleta de processos é monitoramento comportamental detalhado

O daemon varre `/proc` a cada 60 segundos e guarda nomes de processos e horários.
A documentação declara retenção de 30 dias, mas o valor jurídico da coleta,
necessidade, proporcionalidade e acesso precisam ser demonstrados. O Lyra não
tem autorização para assumir que atividade detalhada é necessária para limite
de tempo.

#### BPC-09 — falhas frequentemente viram permissão ou sucesso parcial

Exemplos: filtro malcontent retorna permitido diante de erro; várias operações
privilegiadas usam `|| true`; atualizações de JSON e enforcement não formam uma
transação; criação de conta pode deixar etapas anteriores aplicadas quando uma
posterior falha.

#### BPC-10 — integração e pacote são específicos do BigLinux/Arch

O pacote usa PKGBUILD, hook libalpm, pacman/pamac/yay/paru, suposições de KDE e
unidades/paths próprios. Importá-lo para Leap criaria fork grande e duplicaria
componentes que devem ser avaliados no openSUSE.

## Elementos aproveitáveis conceitualmente

- AccountsService para identidade da conta local, sem confundi-la com aferição;
- malcontent/OARS como política upstream de aplicações, após #110;
- processo de enforcement independente da GUI;
- indicador claro para o usuário supervisionado;
- persistência local e ausência de telemetria/cloud por padrão;
- reaplicação após atualização e testes de resiliência como requisitos;
- distinção entre agenda diária, quota e filtro de aplicativos.

Esses pontos são referências, não dependências escolhidas.

## Matriz de decisão de reuso

| Componente | Decisão | Condição |
|---|---|---|
| GTK/libadwaita | Não importar | UX será integrada ao Vega na #109 |
| AccountsService | Avaliar upstream | Confirmar suporte e contrato no Leap |
| malcontent | Candidato preferencial | Qualificação #110, pacote oficial e testes |
| Daemon Rust | Rejeitar no estado atual | API/autorização/fail-open incompatíveis |
| `group-helper` shell | Rejeitar | Privilégio excessivo e contrato não tipado |
| ACLs | Somente defesa complementar | Nunca fronteira única; cobrir update/bypass |
| PAM `time.conf` | Avaliar | Compatibilidade, recuperação e UX de sessão |
| nftables DNS | Somente defesa complementar | Não prometer cobertura contra DoH/VPN |
| Histórico de processos | Não adotar por padrão | Só após necessidade/proporcionalidade aprovadas |
| Hook libalpm | Não aplicável | Lyra usa RPM/zypper/OBS |

## Requisitos derivados para #110, #111 e #114

1. API por capacidade, autenticada e versionada; nenhum método geral
   `GetAgeGroup(uid)`.
2. Resposta mínima por limiar/finalidade, com consentimento/revogação quando
   definidos juridicamente.
3. Estado desconhecido/corrompido bloqueia e solicita recuperação.
4. Persistência root-only, atômica, sincronizada, sem symlink e com migração.
5. Adaptadores pequenos para AccountsService, malcontent, loja e tempo de uso.
6. Nenhum helper shell privilegiado ou operação de comando/caminho arbitrário.
7. Enforcement deve sobreviver a Vega, reboot, update e rollback.
8. Testes de evasão: CLI, zypper, Flatpak, interpretadores, AppImage,
   containers, update de inode, DoH, VPN e sessão offline.
9. Coleta de atividade desativada por padrão até finalidade e retenção serem
   aprovadas.
10. Portabilidade upstream/openSUSE antes de código exclusivo do Lyra.

## Resultado da #112

A auditoria técnica está concluída para a revisão indicada. Qualquer nova
revisão upstream exige análise diferencial. O resultado desbloqueia pesquisa
da #110 e alimenta a ADR #111, mas não desbloqueia sozinho a implementação
#114: o parecer #106 e as demais dependências continuam obrigatórios.

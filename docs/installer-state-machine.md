# Máquina de estados e contratos do Lyra Installer

Este documento define o fluxo normativo entre interface, planejamento e
serviço privilegiado. A confirmação final já inicia a execução real e mostra
o estado em andamento e os eventos terminais; o streaming de cada evento para
a tela enquanto uma operação longa ainda roda continua pendente na #38.

## Estados

| Estado | Entrada permitida | Saída | Escrita em disco |
|---|---|---|---|
| `Collecting` | idioma, região, teclado e conta | `Discovering` | não |
| `Discovering` | snapshot somente leitura | `Planning` ou `Failed` | não |
| `Planning` | `StorageSnapshot` + `GuidedChoice` | `PlanReady` ou `Failed` | não |
| `PlanReady` | plano e resumo destrutivo | `Confirming` ou volta à coleta | não |
| `Confirming` | validação da configuração e confirmação explícita | `Authorizing` | não |
| `Authorizing` | request serializado + polkit | `Revalidating`, `Cancelled` ou `Failed` | não |
| `Revalidating` | snapshot novo + reconstrução do plano | `Executing` ou `Failed` | não |
| `Executing` | operações tipadas em sequência | `CleaningUp`, `Cancelled` ou `Failed` | sim |
| `CleaningUp` | undo em ordem reversa para mounts e recursos temporários | estado terminal | somente limpeza |
| `Completed` | todas as operações concluídas e limpeza executada | terminal | não |
| `Failed` | erro estruturado e warnings de limpeza | terminal | não |
| `Cancelled` | cancelamento observado entre operações | terminal | não |

Transições diretas de `Collecting`, `Planning` ou `PlanReady` para
`Executing` são inválidas. Nenhuma chamada destrutiva pode ocorrer antes de
`Confirming` e `Revalidating` concluírem.

## Contrato do plano

`PlanBuilder` é uma função pura: recebe snapshot + escolha e retorna
`InstallPlan` ou todos os motivos de bloqueio. O JSON do plano contém
`schema_version`, alvo bruto, camada de volumes, políticas da ESP e de swap,
filesystem, resumo destrutivo e warnings.

Exemplo reduzido:

```json
{
  "schema_version": 3,
  "raw_target": {"Disk": "/dev/sda"},
  "volume_layer": "Direct",
  "esp": {"Create": {"size_bytes": 314572800}},
  "swap": "Zram",
  "root_filesystem": {"Btrfs": {"subvolumes": []}},
  "destructive_summary": {"erased": []},
  "warnings": []
}
```

O exemplo omite subvolumes apenas por legibilidade; um plano real sempre usa
o layout completo produzido pelo builder. O frontend não cria esse objeto à
mão. Versão desconhecida, plano diferente após nova descoberta ou campo
inválido encerra a execução antes da primeira operação.

## Falhas, cancelamento e retomada

- cancelamento é cooperativo e observado entre operações; não interrompe um
  `mkfs`, `unsquashfs` ou outro processo já iniciado;
- `undo` libera mounts e recursos temporários, mas não tenta reconstruir dados
  apagados; o resumo deve deixar essa irreversibilidade explícita;
- falha depois da primeira escrita é terminal. Não existe retomada automática
  na Beta 2: o usuário coleta o log, reinicia o fluxo e gera um plano novo;
- operações de configuração de arquivo devem convergir ao mesmo conteúdo
  quando repetidas; operações destrutivas só podem ser repetidas a partir de
  nova descoberta e confirmação;
- falha de limpeza gera `Warning` e não oculta a falha original;
- `Completed` só é emitido depois da sequência inteira e do unwind.

## Logs e segredos

Eventos podem conter nome da etapa, detalhe técnico não secreto e mensagem de
erro. Eles nunca incluem senha, conteúdo enviado a `chpasswd`, tokens ou
chaves. A senha não entra em argv. A exportação persistente e revisável dos
eventos é parte restante da #38; até ela existir, o serviço escreve somente o
stream JSON Lines consumido pelo frontend.

## Superfície privilegiada

O frontend, descoberta e `PlanBuilder` rodam sem privilégio. O serviço root
aceita apenas o request tipado, revalida o plano e executa binários presentes
em `ALLOWED_BINARIES`, sempre com argv separado. Polkit autoriza somente o
caminho empacotado do serviço. Consulte os ADRs em `docs/adr/` para as razões
e alternativas consideradas.

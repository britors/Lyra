# Vega: progresso e console técnico de operações de software

- Estado: aprovado para implementação na Desktop Alpha 6
- Issue: #115
- Integração: #83, #88 e #103

## Decisão de layout

O Vega usa uma experiência adaptativa:

- em janelas largas, uma gaveta inferior expansível ocupa inicialmente 35% da
  altura e pode crescer até 70%;
- em janelas estreitas, “Mostrar detalhes” abre uma página interna dedicada,
  preservando a barra de progresso e uma ação clara de retorno;
- o progresso resumido permanece utilizável com os detalhes fechados;
- a área técnica se chama **Detalhes da operação** e possui as abas **Eventos**
  e **Console do Zypper**. Ela nunca é apresentada como terminal.

Painel lateral foi rejeitado porque comprime excessivamente mensagens e linhas
do Zypper. Janela de terminal separada foi rejeitada porque perde contexto,
parece interativa e dificulta reconexão e acessibilidade.

## Wireframe — janela larga

```text
┌──────────────────────────────────────────────────────────────────────┐
│ Atualizando o sistema                                      62%       │
│ [✓] Preparando  [✓] Baixando  [●] Instalando  [ ] Finalizando        │
│ Firefox, kernel e mais 84 pacotes · Snapshot #184 criado             │
│                                                                      │
│ Não desligue o computador. A aplicação não pode ser cancelada agora. │
│                                             [Mostrar/ocultar detalhes]│
├──────────────────────────────────────────────────────────────────────┤
│ Detalhes da operação                      [Copiar] [Exportar] [—][▢] │
│ [Eventos] [Console do Zypper]                 Filtro: [Tudo ▾] [⌕]  │
│ 14:32:08  Metadados verificados                                   ✓ │
│ 14:32:11  Snapshot de recuperação criado                          ✓ │
│ 14:32:15  Instalando MozillaFirefox…                             62% │
│                                                        3 novas linhas│
└──────────────────────────────────────────────────────────────────────┘
```

## Wireframe — janela estreita

```text
┌──────────────────────────────┐   ┌──────────────────────────────┐
│ Atualizando             62%  │   │ ‹ Atualização · detalhes    │
│ ● Instalando                 │   │ [Eventos] [Console]          │
│ MozillaFirefox               │ → │ 14:32:11 Snapshot #184      │
│                              │   │ 14:32:15 Installing…         │
│ [Mostrar detalhes]           │   │                              │
└──────────────────────────────┘   │ [Voltar ao final · 3 novas] │
                                   └──────────────────────────────┘
```

## Estados do resumo

| Estado normativo | Título | Ação disponível |
|---|---|---|
| `Checking`/`Preflight` | Verificando o sistema | cancelar |
| `Planned` | Atualização pronta | revisar e confirmar |
| `Downloading` | Baixando pacotes | cancelar com segurança |
| `Snapshotting` | Criando ponto de recuperação | aguardar |
| `Applying`/`ApplyingOffline` | Instalando atualizações | nenhuma interrupção enganosa |
| `AwaitingReboot` | Reinicialização necessária | reiniciar |
| `VerifyingBoot` | Verificando a atualização | ver detalhes |
| `Completed` | Sistema atualizado | fechar/exportar |
| `Blocked` | Atualização bloqueada | corrigir/repetir preflight |
| `Failed` | Não foi possível atualizar | exportar diagnóstico |
| `NeedsRecovery` | Recuperação necessária | revisar rollback |

Autorização Polkit é apresentada fora da gaveta. Fechar o Vega não cancela a
operação; ao reabrir, a UI consulta o último `sequence` recebido e reconstrói
as duas abas.

## Eventos e console

**Eventos** é a aba padrão. Ela consome somente eventos estruturados e
localiza título, explicação, progresso e ação. **Console do Zypper** mostra o
stream técnico sanitizado, com locale neutro do backend. A UI nunca infere
estado, percentual ou sucesso desse texto.

O contrato necessário por linha contém:

- UUID da operação e `sequence` monotônico;
- instante UTC, origem (`zypper-stdout`, `zypper-stderr` ou `service`);
- fase normativa e severidade;
- texto UTF-8 sanitizado;
- indicador de truncamento, nunca conteúdo removido.

## Auto-scroll, busca e filtros

- auto-scroll permanece ativo somente quando a visualização está no final;
- rolar para cima pausa o auto-scroll e mostra “N novas linhas — voltar ao
  final”;
- filtros: tudo, downloads, pacotes, avisos e erros;
- busca é local sobre o buffer sanitizado e não envia texto ao serviço;
- copiar respeita seleção; sem seleção, copia as linhas visíveis;
- exportar usa `lyra-report` e uma segunda sanitização no limite de exportação;
- limpar filtro não apaga o registro persistido.

## Sanitização e retenção

Antes de persistir ou emitir uma linha, o serviço:

1. remove controles C0/C1, exceto tabulação, e todas as sequências ANSI/OSC;
2. remove hyperlinks de terminal e neutraliza retorno de carro/backspace;
3. substitui usuário e caminhos pessoais por marcadores;
4. mascara usuário/senha/query/fragment de URLs;
5. mascara tokens, chaves e valores conhecidos como secretos;
6. limita uma linha a 4 KiB UTF-8 e registra `truncated = true`;
7. limita o buffer persistido a 10.000 linhas ou 4 MiB por operação, mantendo
   eventos normativos e a primeira causa da falha fora desse descarte.

Operações ativas e falhas não reconhecidas não são removidas. Após conclusão,
o padrão da ADR 0007 permanece: três operações mais recentes por até 90 dias.

## Acessibilidade e i18n

- a área possui nome e descrição acessíveis e foco retorna ao controle que a
  abriu;
- novas linhas não usam região `live` assertiva; leitor de tela anuncia apenas
  mudanças normativas de fase;
- estado usa texto e ícone, nunca apenas cor;
- controles e eventos estruturados existem em `en-US`, `pt-BR` e `es-ES`;
- o console é identificado como detalhe técnico em locale neutro;
- atalhos de teclado não capturam combinações globais nem oferecem entrada.

## Critérios de implementação

- o backend entrega replay por `sequence` e stream sanitizado limitado;
- a UI reconecta sem perder estado e sem duplicar linhas;
- não existe widget de terminal, PTY, prompt ou canal de stdin;
- testes finais injetam ANSI/OSC, URLs com credenciais, tokens, linhas longas,
  UTF-8 inválido, alto volume, queda da UI e reinício do serviço;
- nenhum botão sugere cancelamento quando a máquina de estados o proíbe.

# PROMPT DE IMPLEMENTAÇÃO — MIGRAÇÃO ASSISTIDA DO WINDOWS (CALAMARES)

> **Versão:** 1.0
> **Status:** Especificação incremental, pronta para implementação
> **Pré-requisitos:** `PROMPT-LYRA-OS.md` v2.1 (módulo Partition do Calamares já configurado), `PROMPT-LYRA-IDENTIDADE.md` v1.0
> **Escopo:** Este documento ADICIONA um módulo customizado ao Calamares que detecta instalação Windows existente e oferece importar documentos, imagens e favoritos de navegador para o novo usuário do Lyra OS. Não redefine o fluxo geral do instalador — apenas insere uma etapa opcional.

---

## 1. Visão Geral

Grande parte do público-alvo do Lyra OS (usuário não-técnico) chega vindo do Windows, frequentemente por fim de suporte ou troca de máquina. O momento da instalação é a única janela em que o sistema antigo e o novo coexistem fisicamente no mesmo disco — se a migração de dados pessoais não acontecer aqui, não acontece depois.

**Objetivo:** copiar (nunca mover, nunca apagar) uma seleção de conteúdo do Windows detectado para o novo usuário do Lyra OS, com o mínimo de decisões exigidas da pessoa.

### 1.1 Princípios

1. **Não-destrutivo por definição.** O módulo só lê a partição Windows. Nunca escreve, nunca apaga, nunca redimensiona nada nela. A decisão de particionamento (dual-boot, substituir, redimensionar) continua exclusivamente no módulo Partition padrão do Calamares, **antes** deste módulo.
2. **Opcional e reversível na tela.** O usuário pode pular inteiramente sem qualquer efeito colateral.
3. **Cópia, não sincronização contínua.** É um evento único, no momento da instalação — não um vínculo permanente com o Windows.
4. **Transparência total.** A tela mostra exatamente o que foi encontrado e o que será copiado antes de confirmar.

---

## 2. Posição no Fluxo do Calamares

Sequência de módulos (estende a lista do `PROMPT-LYRA-OS.md` §7):

1. Welcome
2. Locale
3. Keyboard
4. Partition
5. **→ Windows Migration (novo — só aparece se detecção positiva, ver §3)**
6. Users
7. Summary
8. (fase de instalação — a cópia efetiva ocorre aqui, ver §5)
9. Finished

- O módulo é **condicional**: se nenhuma instalação Windows for detectada na etapa 4, ele não aparece — o fluxo segue direto para Users, sem tela vazia nem menção ao recurso
- Implementado como módulo Python customizado do Calamares (`viewmodule`), seguindo a convenção de módulos de terceiros do Calamares

---

## 3. Detecção

Executada logo após a confirmação do particionamento (módulo Partition), antes de qualquer formatação:

- Varredura das partições NTFS existentes no disco (via `blkid` + `ntfs-3g` para montagem somente-leitura temporária)
- Critério de detecção positiva: presença de `Windows/System32` e de ao menos um perfil de usuário em `Users/`
- Se múltiplas instalações Windows forem encontradas (raro), listar todas e permitir escolher uma
- Se a partição Windows estiver com **hibernação ativa** (arquivo `hiberfil.sys` não-vazio) ou **BitLocker habilitado**, a montagem somente-leitura é abortada e o módulo exibe aviso explicando o motivo (dados podem estar inconsistentes ou inacessíveis) — nesses casos o módulo se comporta como se não tivesse detectado nada, seguindo direto para Users

---

## 4. Conteúdo Oferecido

Para cada perfil de usuário Windows encontrado em `Users/<nome>` (excluindo perfis de sistema: `Default`, `Public`, `All Users`):

| Origem no Windows | Destino no Lyra OS | Padrão |
|---|---|---|
| `Documents/` | `~/Documentos/Do Windows/` | selecionado |
| `Pictures/` | `~/Imagens/Do Windows/` | selecionado |
| `Videos/` | `~/Vídeos/Do Windows/` | selecionado |
| `Music/` | `~/Música/Do Windows/` | selecionado |
| `Desktop/` | `~/Área de Trabalho/Do Windows/` | selecionado |
| `Downloads/` | `~/Downloads/Do Windows/` | **não** selecionado (geralmente lixo temporário) |
| Favoritos do Chrome/Edge (arquivo `Bookmarks` JSON em `AppData/Local/`) | importação nativa no Firefox via formato HTML de favoritos | selecionado, se encontrado |

- Cada linha é uma opção com checkbox e **tamanho estimado** calculado antes da confirmação (soma de tamanho dos diretórios), para o usuário decidir com informação de espaço em disco
- Perfis com mais de um usuário Windows: escolher qual perfil migrar (o instalador já sabe qual conta está sendo criada no Lyra OS, uma migração por instalação)
- Arquivos de sistema, `AppData` (exceto favoritos de navegador) e instaladores de programas **nunca** são oferecidos — não fazem sentido em outro sistema operacional

---

## 5. Execução da Cópia

- A cópia efetiva ocorre na **fase de instalação** (módulo `viewmodule` correspondente do tipo job, executado após Summary), não no momento da seleção — mesma convenção do Calamares para todas as operações demoradas
- Montagem somente-leitura da partição NTFS mantida durante toda a fase de instalação, desmontada ao final
- Progresso reportado na barra de instalação padrão do Calamares, com rótulo "Copiando seus arquivos do Windows..."
- Cópia via `rsync` (preserva estrutura, tolera interrupção, retomável) rodando em processo do próprio Calamares (já roda como root nesta fase — sem necessidade de mecanismo de privilégio adicional)
- Favoritos de navegador: conversão do JSON do Chrome/Edge para HTML padrão (formato Netscape Bookmark), gravado em `~/.mozilla/firefox/<perfil>/bookmarks-importados.html`; primeira execução do Firefox (via Lyra Tour ou manual) pode importar automaticamente — ver prompt de tela adicional do Lyra Tour
- **Falha parcial não aborta a instalação:** se um diretório falhar ao copiar (arquivo corrompido, permissão NTFS estranha), registrar no log e continuar com o restante; o resumo final (§6) informa o que não pôde ser copiado

---

## 6. Comunicação ao Usuário

### 6.1 Tela de seleção (durante a fase interativa)

- Título: "Encontramos uma instalação do Windows"
- Texto introdutório curto: explicar que os arquivos serão **copiados** (nunca movidos) e que o Windows não será alterado
- Lista de checkboxes conforme §4, com tamanho estimado por item e total acumulado
- Aviso permanente na tela: "Nada será apagado do Windows"
- Botão "Pular esta etapa" com o mesmo peso visual dos demais botões — não é um link discreto disfarçando a opção

### 6.2 Tela de resumo pós-instalação

Ao final da instalação (tela Finished, complementando o resumo padrão do Calamares):

- "Seus arquivos do Windows foram copiados para as pastas 'Do Windows' dentro de Documentos, Imagens, Vídeos e Música"
- Se houve falha parcial: "Alguns arquivos não puderam ser copiados — [ver detalhes]" com link para o log completo
- Menção de que os favoritos foram preparados para importação no Firefox

---

## 7. Estrutura do Módulo Calamares

```
calamares-lyra-winmigrate/
├── module.desc                    # descriptor do viewmodule, tipo Python
├── main.py                        # lógica de detecção, listagem, cálculo de tamanho
├── main.qml                       # tela QML de seleção (visual consistente com branding Lyra via variáveis do slideshow)
├── winmigrate.conf                # mapeamento origem→destino (§4), configurável sem recompilar
├── jobs/
│   └── copy_job.py                # job de cópia executado na fase de instalação (rsync + conversão de bookmarks)
└── tests/
    ├── detection.test.py          # detecção positiva/negativa, múltiplos perfis, BitLocker/hibernação
    └── copy_job.test.py           # cópia com falha parcial não aborta; conversão de bookmarks válida
```

- Empacotado junto ao branding do instalador (`lyra-branding`, §4.5 do `PROMPT-LYRA-IDENTIDADE.md`) ou como pacote próprio `calamares-lyra-winmigrate`, dependência do meta-pacote do instalador — a decisão de empacotamento fica a critério da implementação, sem impacto no comportamento

---

## 8. Validação

- [ ] Instalação em disco sem Windows: módulo não aparece, fluxo segue direto Partition → Users
- [ ] Instalação em disco com Windows 10/11 padrão: detecção positiva, tela de seleção exibida com tamanhos corretos
- [ ] Disco com BitLocker habilitado: módulo trata como não-detectado, sem travar o instalador
- [ ] Disco com hibernação ativa: mesmo comportamento acima
- [ ] Múltiplos perfis de usuário Windows: seleção de perfil exibida corretamente
- [ ] "Pular esta etapa": instalação prossegue normalmente, nenhum arquivo copiado, nenhuma alteração na partição Windows
- [ ] Pós-instalação: arquivos aparecem exatamente nos destinos de §4; partição Windows permanece bit-a-bit inalterada (verificação por hash antes/depois em ambiente de teste)
- [ ] Falha simulada em um arquivo específico: instalação completa, resumo final relata a falha, demais arquivos presentes
- [ ] Favoritos do Edge/Chrome convertidos geram HTML válido, importável manualmente no Firefox
- [ ] Tempo total de cópia de um perfil de ~10 GB não deve travar a UI da fase de instalação (progresso segue atualizando)

---

## 9. Fora de Escopo

- Importação de e-mails (Outlook) — complexidade de formatos proprietários, considerar futuramente
- Importação de senhas salvas de navegador — risco de segurança em cópia não-interativa; fora de escopo permanentemente, a menos que via mecanismo explícito e criptografado
- Migração de configurações de aplicativos Windows (não fazem sentido em outro SO)
- Suporte a discos com criptografia de terceiros além de BitLocker (VeraCrypt etc.)

---

**Fim da especificação.**

# ADR 0001: frontend Tauri/WebKitGTK sem privilégio

- Estado: aceita
- Data: 2026-08-08
- Issue: #35

## Contexto

O instalador precisa integrar-se ao GNOME, preservar a interface visual já
construída em HTML/CSS e limitar o código executado como root. Executar a
janela inteira com privilégio amplia a superfície de ataque para WebKit,
renderização, entrada do usuário e assets.

## Decisão

Usar Rust + Tauri 2 com HTML/CSS/JavaScript estático servido pelo WebKitGTK do
sistema. `lyra-installer` roda como `liveuser`. Somente
`lyra-installer-service`, um binário separado e sem interface, é iniciado por
`pkexec` após a confirmação explícita do plano.

O frontend pode descobrir armazenamento, construir dry-run e validar dados,
mas não chama ferramentas de disco nem abre uma shell. A ação polkit é presa
ao caminho `/usr/libexec/lyra-installer-service`.

## Consequências

- a interface permanece responsiva e não herda privilégio;
- o limite UI/root é um protocolo serializável e testável;
- Tauri/WebKitGTK passam a ser dependências de build e runtime;
- progresso precisa ser encaminhado pelo protocolo, não por acesso direto ao
  estado do backend;
- GTK/libadwaita puro exigiria reescrever a interface, e Electron adicionaria
  um runtime redundante; ambos ficam rejeitados para a Beta 2.

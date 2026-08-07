# Lyra Installer

Frontend nativo do instalador do Lyra OS, escrito em Rust com Tauri 2. A
interface é HTML/CSS/JavaScript estático servido pelo WebKitGTK do sistema,
com o núcleo de domínio e a futura ponte privilegiada em Rust. Neste primeiro
estágio ele implementa a navegação do assistente, os padrões de produto
(`pt_BR.UTF-8` e `lyra-os`) e a validação dos dados da conta sem executar
nenhuma operação destrutiva.

```bash
cd installer
cargo test
cargo tauri dev
```

O comando `cargo tauri dev` abre o layout visual em Tauri. O build não depende
de fontes ou recursos remotos: as telas e todos os estilos ficam em `ui/`.

O executável gráfico sempre roda como o usuário da sessão live. Operações de
disco serão expostas por um serviço separado, com uma API tipada e pequena,
autorizada por polkit. A interface não deve chamar ferramentas de disco por
meio de uma shell nem ser iniciada inteira com `pkexec`.

O Calamares continua sendo o instalador ativo da imagem de desenvolvimento
enquanto o serviço Tauri/Rust não implementa e valida todo o pipeline descrito em
[`../docs/installer-architecture.md`](../docs/installer-architecture.md).

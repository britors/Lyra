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

`lyra-installer-core::storage` já cobre a descoberta de discos, RAID (mdadm)
e LVM (`pvs`/`vgs`/`lvs`) e a montagem de um plano de instalação declarativo
em dry-run — só leitura, sem executar nada destrutivo. `cargo test` cobre
esse módulo com fixtures (disco vazio, ocupado, ESP existente, espaço
insuficiente, RAID saudável/degradado, RAID+LVM combinados). O comando Tauri
`discover_storage` expõe essa leitura para a UI; nenhuma tela nova para
escolher o destino de disco existe ainda.

O Calamares continua sendo o instalador ativo da imagem de desenvolvimento
enquanto o serviço Tauri/Rust não implementa e valida todo o pipeline descrito em
[`../docs/installer-architecture.md`](../docs/installer-architecture.md).

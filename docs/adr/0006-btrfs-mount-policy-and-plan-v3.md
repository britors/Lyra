# ADR 0006: política Btrfs global, NOCOW granular e plano versão 3

- Estado: aceita
- Data: 2026-08-09

## Contexto

O plano antigo escrevia `compress=zstd` na maioria das linhas do `fstab`, mas
`nodatacow` nas linhas dos subvolumes de bancos e imagens de máquinas
virtuais. Essa aparência de política por subvolume não corresponde ao contrato
do Btrfs: opções específicas como `compress` e `nodatacow` são compartilhadas
pelo filesystem e, normalmente, somente o primeiro subvolume montado define o
valor efetivo.

Também foram avaliados `discard=async`, `space_cache=v2`, `noatime` e `ssd`.
O kernel usado pela Beta 2 já habilita descarte assíncrono quando suportado,
usa free-space-tree v2 por padrão, mantém `relatime` e detecta SSD. Repetir
essas opções não cria uma garantia adicional e dificultaria distinguir política
intencional de defaults do kernel.

## Decisão

Todas as linhas Btrfs geradas pelo instalador usam a constante única
`compress=zstd:3`. O nível 3 é o default atual do Zstd no Btrfs, mas fica
explícito para que uma mudança upstream não altere silenciosamente a política
da distribuição.

Subvolumes vazios destinados a MariaDB/MySQL, PostgreSQL e imagens libvirt
recebem `chattr +C` imediatamente após a criação. Arquivos criados depois
herdam NOCOW desse diretório sem desligar compressão e checksums no restante
do filesystem. `e2fsprogs`, que fornece `chattr`, torna-se dependência explícita
da imagem e o binário entra na allow-list do serviço privilegiado.

Como um serviço versão 2 interpretaria `nodatacow` como opção de mount, o
`INSTALL_PLAN_SCHEMA_VERSION` passa de 2 para 3. Frontend e serviço precisam
ser atualizados juntos; planos destrutivos antigos não são migrados.

## Consequências

- mount inicial, mounts do instalador e `fstab` deixam de se contradizer;
- Snapper e rollback continuam usando uma única política global;
- `nodatacow` deixa de aparecer no `fstab`, mas permanece uma intenção tipada
  e testada no plano;
- `discard=async`, `space_cache=v2`, `noatime` e `ssd` só serão adicionados se
  medições repetíveis demonstrarem necessidade no kernel suportado;
- instalações existentes não são alteradas automaticamente. Uma migração
  precisa primeiro provar que os diretórios estão vazios ou tratar arquivos
  já existentes, pois `chattr +C` não reescreve extents antigos.

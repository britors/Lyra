# Erro de instalação do Lyra OS

Registrado em 5 de agosto de 2026 a partir da captura `erro.png`.

O instalador falhou ao executar:

```text
/usr/bin/snapper --no-dbus -c root create-config /
```

O comando terminou com código `1` e apresentou a saída:

```text
setmntent failed
Detecting filesystem type failed.
```

## Causa confirmada

O artefato final do KIWI não continha `/etc/mtab`. O Snapper ainda consulta
esse caminho durante `create-config` para localizar o ponto de montagem e
detectar o tipo do sistema de arquivos raiz. A ausência do arquivo produz
diretamente `setmntent failed` e, em seguida, `Detecting filesystem type
failed.`

## Correção

`kiwi/config.sh` agora cria o link padrão:

```text
/etc/mtab -> ../proc/self/mounts
```

O link funciona tanto na sessão live quanto no chroot do sistema-alvo, onde
`/proc` já é montado pelo módulo `mount` do Calamares. O script de build e
teste também valida o link antes de aceitar e copiar a nova ISO.

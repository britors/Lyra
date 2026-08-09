# Diagnóstico seguro com lyra-report

`lyra-report` coleta informações para investigar falhas da sessão live e do
sistema instalado. Ele só é iniciado pelo usuário, não possui serviço ou timer,
não usa a rede e nunca envia arquivos automaticamente.

## Criar e revisar um relatório

Execute como usuário comum:

```bash
lyra-report
```

A ferramenta coleta os dados em um diretório temporário privado, anonimiza o
conteúdo, apaga a coleta bruta e mostra todos os arquivos saneados em um pager.
Depois da revisão, responda `y` para criar o arquivo local ou use qualquer outra
resposta para cancelar. No cancelamento, nenhum arquivo de diagnóstico fica no
diretório atual.

Para escolher o destino:

```bash
lyra-report --output ~/lyra-report-beta2.tar.gz
```

`--yes` pula a interação e existe para uma coleta não interativa que já tenha
sido aprovada explicitamente. Ele não faz upload. O arquivo final sempre tem
permissão `0600`.

## Conteúdo

O relatório identifica a versão do Lyra e se está na sessão live ou no sistema
instalado. Também inclui:

- CPU, memória, PCI, USB e discos sem números de série;
- boot, Secure Boot, EFI, initramfs, serviços com falha e journal recente;
- estado dos dispositivos de rede sem perfis, senhas ou nomes de conexão;
- repositórios, inventário RPM e estado explícito de todos os pacotes próprios
  do ecossistema Lyra, incluindo Prosa e Calco publicados no OBS mesmo quando
  não estão instalados na imagem;
- mounts, `fstab`, Btrfs, Snapper e GRUB;
- disponibilidade e logs legíveis do Lyra Installer.

Comandos ausentes ou dados sem permissão ficam registrados como falhas de
coleta; isso não interrompe as demais seções.

## Anonimização e limites

Antes da revisão, o redator substitui senhas, tokens, cabeçalhos de autorização,
credenciais em URLs, chaves privadas, SSIDs, usuários, diretórios home,
hostnames, e-mails, endereços IP/MAC e UUIDs. Valores repetidos recebem o mesmo
marcador, como `<ipv4-1>`, para preservar relações úteis ao diagnóstico.

Nenhuma anonimização automática é perfeita. Leia o `README.txt`, o
`redaction-summary.txt` e os demais arquivos antes de compartilhar.

## Anexar a uma issue

1. Abra a issue correspondente no GitHub e descreva como reproduzir o problema.
2. Confirme que a issue não é pública ou contém apenas informações que você
   aceita compartilhar.
3. Arraste o `.tar.gz` revisado para o campo de comentário.
4. Cancele o comentário se o anexo ou o texto ainda mostrar informação pessoal.

O Lyra não recebe o relatório até que o próprio usuário conclua manualmente
esse envio no GitHub ou em outro canal escolhido por ele.

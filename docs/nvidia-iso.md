# ISO NVIDIA — proposta cancelada

A proposta de uma ISO Desktop separada com o driver proprietário NVIDIA foi
cancelada em 14/08/2026. O Lyra OS mantém **uma única ISO Desktop**. O suporte
proprietário opcional é instalado depois da instalação pelo Vega e pertence à
Desktop Alpha 5.

Este arquivo preserva somente as descobertas técnicas que continuam válidas
para o fluxo do Vega. Ele não autoriza criar profile KIWI, nome de imagem,
artefato, repositório de imagem ou gate de release separado.

## Contrato do fluxo Vega

- detectar conservadoramente GPU G06 suportada e bloquear hardware incerto;
- exigir confirmação explícita;
- verificar o estado do Secure Boot;
- criar snapshot Snapper somente leitura antes da primeira mudança;
- usar exclusivamente pacotes RPM do repositório oficial NVIDIA para Leap;
- instalar `nvidia-open-driver-G06-signed-kmp-meta` e
  `nvidia-userspace-meta-G06` em conjunto;
- rejeitar instalação parcial ou versões desalinhadas;
- executar `dracut --force`, orientar o reinício e preservar rollback;
- após o reboot, verificar módulo ativo, `nvidia-smi`, Wayland e conectores
  DRM antes de declarar sucesso.

## Descobertas preservadas

Testes anteriores encontraram um caso real em que o módulo assinado estava na
versão `580.159.03`, enquanto `nvidia-video-G06`, `nvidia-gl-G06` e
`nvidia-common-G06` permaneciam em `570.172.08`. O firmware GSP esperado não
existia e a saída HDMI ligada à GPU dedicada falhou. Os metapacotes de KMP e
userspace em lockstep corrigiram o cenário.

Logo, atualizar apenas o KMP não é suportado. Kernel, módulo, userspace e
firmware precisam permanecer compatíveis; uma atualização de kernel sem KMP
publicado deve ser bloqueada antes da transação.

## Gate mínimo

- GPU NVIDIA real, incluindo o notebook híbrido disponível;
- Secure Boot ligado e desligado;
- instalação, reboot, `nvidia-smi`, Wayland e monitor externo;
- atualização conjunta de kernel/driver;
- falha parcial injetada e rollback para uma baseline inicializável;
- evidência revisável sem credenciais.

O fluxo não é declarado suportado enquanto qualquer item acima estiver sem
evidência ou houver P0/P1 aberto.

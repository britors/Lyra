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
- rejeitar instalação parcial ou versões desalinhadas, auditando todos os
  RPMs G06 efetivos e não apenas os metapacotes;
- executar `dracut --force`, orientar o reinício e preservar rollback;
- após o reboot, verificar módulo ativo, `nvidia-smi`, Wayland e conectores
  DRM antes de declarar sucesso;
- qualificar suspensão por versão e topologia gráfica, bloqueando-a de forma
  reversível quando houver regressão conhecida;
- reconciliar a política no início do `vegad`, inclusive após atualizações que
  não tenham sido iniciadas pela tela NVIDIA.

## Descobertas preservadas

Testes anteriores encontraram um caso real em que o módulo assinado estava na
versão `580.159.03`, enquanto `nvidia-video-G06`, `nvidia-gl-G06` e
`nvidia-common-G06` permaneciam em `570.172.08`. O firmware GSP esperado não
existia e a saída HDMI ligada à GPU dedicada falhou. Os metapacotes de KMP e
userspace em lockstep corrigiram o cenário.

Logo, atualizar apenas o KMP não é suportado. Kernel, módulo, userspace e
firmware precisam permanecer compatíveis; uma atualização de kernel sem KMP
publicado deve ser bloqueada antes da transação.

Em 16/08/2026, o notebook híbrido Acer Nitro AN515-57 reproduziu uma segunda
classe de falha com a pilha `580.159.03`: durante a suspensão, o módulo NVIDIA
falhou em `mmuWalkUnmap`/`gpuSanityCheckRegisterAccess`, manteve o GNOME Shell
preso no kernel e provocou soft lockups. SMART, log NVMe, contadores Btrfs e um
scrub completo não encontraram erro de armazenamento. Essa combinação fica em
quarentena de suspensão e hibernação até uma versão posterior passar pelo gate.

A quarentena usa exclusivamente o drop-in gerenciado
`/etc/systemd/sleep.conf.d/90-lyra-nvidia-quarantine.conf`. O Vega só remove o
arquivo se o marcador de propriedade estiver presente, e o remove
automaticamente quando uma versão qualificada substitui a versão afetada.

## Gate mínimo

- GPU NVIDIA real, incluindo o notebook híbrido disponível;
- Secure Boot ligado e desligado;
- instalação, reboot, `nvidia-smi`, Wayland e monitor externo;
- suspensão e retomada controladas, sem soft lockup, erro NVRM, falha de freeze
  ou incremento inesperado de desligamentos inseguros;
- aplicação e remoção automática da quarentena em versões bloqueada/aprovada;
- atualização conjunta de kernel/driver;
- falha parcial injetada e rollback para uma baseline inicializável;
- evidência revisável sem credenciais.

O fluxo não é declarado suportado enquanto qualquer item acima estiver sem
evidência ou houver P0/P1 aberto.

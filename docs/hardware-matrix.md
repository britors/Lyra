# Matriz de hardware da Beta 2

O gate da Beta 2 exige a instalação da mesma ISO candidata em pelo menos um
desktop e dois notebooks distintos. A matriz combinada precisa cobrir CPUs e
gráficos Intel e AMD. NVIDIA com a pilha aberta deve ser registrada quando
disponível, mas não substitui a cobertura Intel/AMD nem depende da ISO NVIDIA
proprietária planejada para outro ciclo.

Cada máquina usa um identificador não pessoal, como `notebook-intel-1`. Não
registre número de série, hostname, usuário, MAC, SSID ou endereço IP.

## Registrar uma máquina

Copie o nome, SHA-256 e commit do manifesto da ISO candidata. Depois de
instalar, atualizar e exercitar o equipamento, execute no sistema instalado:

```sh
lyra-hardware-matrix record \
  --output notebook-intel-1.json \
  --machine notebook-intel-1 \
  --kind notebook \
  --iso-filename lyra-os.x86_64-2026.08-beta2.iso \
  --iso-sha256 COLE_O_SHA256 \
  --source-commit COLE_O_COMMIT \
  --check installation=passed \
  --check update=passed \
  --check suspend-resume=passed \
  --check network=passed \
  --check audio-output=passed \
  --check shutdown=passed \
  --check reboot=passed \
  --check microphone=passed \
  --check bluetooth=passed \
  --check webcam=passed \
  --check printing=not-applicable:sem-impressora-disponivel \
  --check external-display=passed \
  --check wifi=passed \
  --check brightness=passed \
  --check battery=passed \
  --check touchpad=passed
```

Um dispositivo ausente pode ser `not-applicable`, sempre com justificativa.
Instalação, atualização, suspensão/retorno, rede, áudio, desligamento e reboot
nunca podem ser pulados. Um resultado `failed` exige detalhe reproduzível ou
o número da issue e mantém a máquina vermelha.

A ferramenta detecta somente as categorias de fabricante da CPU/GPU; não
coleta identificadores do equipamento. Anexe um `lyra-report` revisado à issue
se uma falha precisar de logs.

## Agregar o gate

Depois dos três ou mais cenários:

```sh
lyra-hardware-matrix aggregate \
  --output hardware-matrix-result.json \
  desktop-amd.json notebook-intel-1.json notebook-amd-1.json
```

A agregação falha se as máquinas não forem distintas, usarem ISOs diferentes,
faltarem desktop/notebooks, não houver cobertura Intel/AMD ou qualquer teste
obrigatório estiver ausente, pulado ou falhando. Somente o JSON agregado deve
ser entregue como `hardware-matrix` ao manifesto final de evidências.

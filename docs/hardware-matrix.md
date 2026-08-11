# Matriz de hardware

A meta ideal do gate é a instalação da mesma ISO candidata em pelo menos um
desktop e dois notebooks distintos, cobrindo CPUs e gráficos Intel e AMD.
NVIDIA com a pilha aberta deve ser registrada quando disponível, mas não
substitui a cobertura Intel/AMD nem depende da ISO NVIDIA proprietária
planejada para outro ciclo.

**Situação real:** o projeto tem hoje um único mantenedor e uma única
máquina física disponível para teste (o restante do fluxo é VM/QEMU via
`kiwi/test/build-and-run-vm.sh`). A meta ideal acima não é alcançável
sozinha. Isso é um risco aceito e documentado, não um bug do processo:
`lyra-hardware-matrix aggregate` continua exigindo que os cenários testados
tenham passado, mas não bloqueia mais a geração de evidência por falta de
forma física ou fornecedor — em vez disso, registra a lacuna no campo
`coverage.gap` do JSON agregado (ex.: `["notebooks<2", "cpu:intel",
"gpu:intel"]` para uma única máquina desktop AMD). O manifesto final de
evidências (`scripts/image-build.py artifact-manifest`) aceita esse
resultado como `hardware-matrix` válido. Se surgirem testadores externos com
hardware diferente, revisitar esta seção e voltar a perseguir a meta ideal.

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

Com um ou mais cenários disponíveis (hoje, tipicamente um só):

```sh
lyra-hardware-matrix aggregate \
  --output hardware-matrix-result.json \
  only-physical-machine.json
```

A agregação falha se as máquinas não forem distintas, usarem ISOs diferentes
ou qualquer teste obrigatório estiver ausente, pulado ou falhando — mas não
mais por faltar desktop/notebooks ou cobertura Intel/AMD; essa lacuna vai
para `coverage.gap` em vez de bloquear. Somente o JSON agregado deve ser
entregue como `hardware-matrix` ao manifesto final de evidências.

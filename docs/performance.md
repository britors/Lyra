# Baseline e orçamento de desempenho

As medições da Beta 2 são locais e opt-in. `lyra-performance` não possui
serviço, timer, telemetria ou envio remoto. Cada captura JSON identifica versão,
commit da imagem, kernel e ambiente de referência.

## Ambiente de referência

Use o mesmo host e a mesma configuração em todas as repetições:

- QEMU/KVM com máquina `q35`, UEFI e CPU `host`;
- 4 vCPUs, 8 GiB de RAM e disco virtio novo de 20 GiB;
- ISO e commit idênticos em toda a série;
- rede disponível, sem outras VMs ou carga pesada concorrente;
- cinco boots novos para `live`, cinco para `installed` e cinco instalações;
- 30 segundos de estabilização e janela de amostragem de 10 segundos.

Uma série mistura resultados somente quando fase, versão, commit, kernel, CPU,
memória e virtualização são idênticos e o build vem de uma árvore limpa.
Coeficiente de variação acima de 10%
invalida a série e exige repetição em um ambiente menos ruidoso.

## Captura

Na sessão a medir:

```bash
mkdir -p ~/lyra-performance/live
lyra-performance capture \
  --phase live \
  --output ~/lyra-performance/live/run-01.json
```

Repita com arquivos `run-02.json` até `run-05.json`. Para o primeiro boot do
sistema instalado, use `--phase installed`.

O tempo até o desktop usa a ativação monotônica de
`graphical-session.target`, com o início do processo `gnome-shell` como
fallback. O tempo de userspace vem do systemd. RAM idle é
`MemTotal - MemAvailable` após a estabilização. CPU e I/O são amostrados
durante a janela configurada. O JSON também preserva `systemd-analyze blame`,
critical chain e os processos que mais consomem CPU para explicar regressões.

O gate do instalador deve converter seus eventos estruturados em
`/run/lyra-performance/installation.jsonl`, cobrindo armazenamento, cópia do
rootfs, configuração do target, boot e finalização. Depois de uma instalação,
capture a série com:

```bash
lyra-performance capture \
  --phase installation \
  --trace /run/lyra-performance/installation.jsonl \
  --output ~/lyra-performance/install/run-01.json
```

## Agregação e baseline

```bash
lyra-performance aggregate \
  --output ~/lyra-performance/live-summary.json \
  ~/lyra-performance/live/run-*.json
```

O resumo registra mediana, desvio absoluto mediano, coeficiente de variação,
mínimo e máximo. Após revisão, o primeiro conjunto da Beta 2 deve ser publicado
em `performance/baselines/` com o manifesto da ISO correspondente.

Para comparar um conjunto posterior:

```bash
lyra-performance aggregate \
  --baseline performance/baselines/2026.08-beta2-live-qemu.json \
  --output ~/lyra-performance/live-current.json \
  ~/lyra-performance/live-current/run-*.json
```

O orçamento versionado em [`performance.toml`](../performance.toml) alerta em
10% e bloqueia em 20% para boot, RAM e duração da instalação. CPU permite 15%
e 30%. I/O permanece informativo porque maior atividade pode significar mais
trabalho útil, não necessariamente regressão.

## Regras para otimizações

Mudanças das issues #28 e #29 devem anexar resumos antes/depois feitos no mesmo
ambiente. Uma melhoria só avança quando a série é estável e os testes de boot,
atualização, Snapper e rollback continuam verdes. Ganho isolado não compensa
falha funcional ou perda de recuperabilidade.

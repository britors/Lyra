# PROMPT DE IMPLEMENTAÇÃO — LYRA OS: ADIÇÃO DO LINUXTOYS

> **Versão:** 1.0
> **Status:** Especificação incremental, pronta para implementação
> **Pré-requisitos:** `PROMPT-LYRA-OS.md` v2.1, `PROMPT-LYRA-ISO-SETUP-HOST.md` v1.0
> **Escopo:** Este documento adiciona o pacote **`linuxtoys-bin`** (AUR) como aplicativo pré-instalado no Lyra OS. Não redefine nada do sistema — apenas integra mais um pacote AUR ao ISO, seguindo exatamente a convenção já usada para Prosa e Fina.

---

## 1. O que é

**LinuxToys** é uma coleção de ferramentas com interface gráfica (GTK3 + Zenity) que simplifica tarefas comuns do dia a dia em distros Linux: instalação assistida de drivers, tweaks de sistema, configuração de contêineres (Distrobox), lançadores de jogos, e scripts utilitários diversos — mantido pelo desenvolvedor `psygreg`, projeto com suporte nativo a localização em português.

- **Origem:** AUR, pacote `linuxtoys-bin` — https://aur.archlinux.org/packages/linuxtoys-bin
- **Natureza:** projeto de terceiros, **não** faz parte do ecossistema Lyra/W3TI — é uma integração de conveniência, como qualquer outro app AUR que o Lyra OS decida pré-instalar
- **Licença/manutenção:** mantido upstream por `psygreg`; o Lyra OS apenas consome o pacote já publicado, sem fork nem modificação

### 1.1 Por que faz sentido no Lyra OS

- É um "canivete suíço" de tarefas que usuário não-técnico não saberia resolver via terminal
- Tem suporte nativo a português, alinhado ao público-alvo do projeto
- Cobre casos que nenhum componente do ecossistema Lyra cobre hoje: lançadores de jogos, ambientes Distrobox, integração com domínios Active Directory

### 1.2 Ponto de atenção — sobreposição parcial com o Vega

Algumas ferramentas do LinuxToys tocam território que o módulo **Hardware e Drivers** e o módulo **Kernel** do Vega (`PROMPT-VEGA.md` §3.3, §3.4) já cobrem — por exemplo, instalação de driver de GPU e troca de kernel. Isso não impede a integração, mas registra-se aqui como ponto a observar:

- O Vega continua sendo a ferramenta **recomendada e integrada ao fluxo do sistema** para essas tarefas (com snapshot automático antes de agir, conforme já especificado)
- O LinuxToys é oferecido como ferramenta **complementar e independente**, útil sobretudo para os casos que o Vega não cobre (jogos, Distrobox, AD)
- Nenhuma ação deste documento tenta unificar ou remover a sobreposição — é uma decisão de produto que pode ser revisitada depois, se gerar confusão real de usuários (ex.: dois botões "trocar kernel" em lugares diferentes)

---

## 2. Integração no Repositório `lyra-iso`

### 2.1 `setup-build-host.sh`

Adicionar à lista já existente de pacotes AUR buildados no host:

```diff
 LYRA_AUR_PACKAGES=(
     "prosa"
     "fina"
+    "linuxtoys-bin"
 )
```

- Nenhuma outra linha do script muda — o mecanismo já existente (`yay -S --needed --noconfirm`, cópia do `.pkg.tar.zst` para o repositório local) trata este pacote exatamente como trata Prosa e Fina hoje

### 2.2 `packages.aur.lock`

```diff
+ linuxtoys-bin=<versão publicada>
```

- Preencher com a versão real no momento do build (verificar o `pkgver` atual do PKGBUILD publicado)

### 2.3 `packages.x86_64`

Nenhuma entrada própria necessária — como pacote AUR, `linuxtoys-bin` é resolvido via `packages.aur.lock` (mesma convenção de Prosa/Fina), não listado diretamente em `packages.x86_64`.

### 2.4 Dependências transitivas

O Pacman resolve automaticamente as dependências do próprio `linuxtoys-bin` durante a instalação (`bash`, `git`, `curl`, `wget`, `zenity`, `python`, `python-gobject`, `python-requests`, `gtk3`, `vte3`) — **nenhuma delas precisa ser listada manualmente** em `packages.x86_64`. Vale registrar que:

- `zenity`, `python-gobject` e `vte3` **não fazem parte** do grupo `gnome` nem de nenhum pacote já especificado no `PROMPT-LYRA-OS.md` — serão instalados como dependências novas no sistema, aumentando levemente o tamanho da instalação base
- `gtk3` já é trazido transitivamente por diversos componentes do GNOME — sem impacto adicional relevante

### 2.5 Visibilidade no sistema

- O pacote já traz seu próprio `.desktop` entry — nenhuma ação adicional necessária para aparecer no Activities Overview do GNOME
- Nenhuma integração especial com Vega ou Lyra Tour é criada por este documento (ver §1.2) — o LinuxToys aparece como um aplicativo independente, não como um módulo do Vega

---

## 3. Validação

- [ ] `linuxtoys-bin` builda com sucesso via `setup-build-host.sh` atualizado
- [ ] Pacote presente no repositório local (`~/.local/share/lyra-repo/`)
- [ ] ISO gerado: `pacman -Qi linuxtoys-bin` presente na instalação
- [ ] Ícone do LinuxToys aparece no Activities Overview do GNOME
- [ ] Aplicativo abre sem erro em instalação limpa do Lyra OS
- [ ] Dependências (`zenity`, `python-gobject`, `vte3` etc.) instaladas corretamente, sem conflito com pacotes já presentes no sistema
- [ ] `grep -ri lyrae airootfs/` continua retornando vazio (checagem de regressão padrão)

---

## 4. Fora de Escopo

- Qualquer integração visual ou funcional entre LinuxToys e Vega (ex.: unificar módulos de kernel/driver) — decisão de produto futura, não coberta aqui
- Tradução ou modificação do LinuxToys — é consumido como está, upstream
- Curadoria de quais scripts específicos do LinuxToys são "recomendados" para o público do Lyra OS — fica a critério do próprio app e do usuário

---

**Fim da especificação.**

# Memorial descritivo do Lyra OS e do Vega

**Documento informativo destinado à avaliação jurídica**

**Data de referência:** 18 de agosto de 2026

**Natureza:** descrição factual preliminar; não contém conclusões jurídicas

## 1. Objeto

Este memorial apresenta as características essenciais do Lyra OS e do Vega para
subsidiar parecer jurídico sobre a incidência da Lei nº 15.211/2025, de seus
regulamentos, da Lei Geral de Proteção de Dados Pessoais e das demais normas
aplicáveis à proteção de crianças e adolescentes em ambientes digitais.

Solicita-se que o parecerista valide o enquadramento jurídico dos fatos aqui
descritos. Expressões como sistema operacional, loja de aplicações, fornecedor,
controlador ou operador não são empregadas neste documento como conclusões.

## 2. Identificação do projeto

O Lyra OS é uma distribuição Linux para computadores pessoais, gratuita e de
código aberto, baseada no openSUSE. Sua proposta é oferecer um ambiente desktop
estável, previsível e de longa duração, integrando componentes mantidos pelo
projeto e por comunidades ou fornecedores independentes.

O projeto seleciona e configura pacotes, produz imagens de instalação, mantém a
identidade visual do produto e define políticas de atualização e integração.
Não desenvolve todo o software incluído na distribuição e não exerce controle
editorial ou operacional sobre todos os projetos e repositórios externos.

O Vega é a central de configurações do Lyra. Entre outras funções administrativas,
ele apresenta informações sobre programas disponíveis e pode iniciar operações
de instalação, remoção e atualização por meio dos mecanismos de gerenciamento de
pacotes do sistema. O processamento privilegiado ocorre em serviço separado da
interface gráfica e está sujeito à autorização do sistema operacional.

## 3. Cadeia técnica de distribuição de software

No fluxo baseado em RPM, o Vega consulta metadados de repositórios configurados
e solicita operações executadas pelos componentes zypper e libzypp do openSUSE.
Os pacotes podem ser produzidos pelo Lyra, pelo openSUSE ou por outras origens
expressamente configuradas. A interface não hospeda necessariamente o arquivo
instalado e não cria automaticamente sua classificação indicativa.

Há intenção de avaliar suporte a Flatpak. Nessa hipótese, a interface poderá
consultar um catálogo remoto e solicitar a instalação do aplicativo por meio do
serviço Flatpak. O suporte ainda deverá ser delimitado tecnicamente e submetido
à avaliação jurídica antes de sua disponibilização.

Também é possível que um administrador utilize diretamente ferramentas de linha
de comando. O parecer deverá considerar se e em que medida as obrigações devem
ser impostas em camada comum do sistema, de modo a evitar que uma proteção exista
somente na interface gráfica.

## 4. Modelo de contas e administração

O computador pode possuir uma ou mais contas locais. Uma conta administrativa
pode autorizar alterações do sistema. Contas comuns não devem receber poderes
privilegiados sem autenticação ou autorização apropriada.

O projeto pretende avaliar um modelo de supervisão no qual um responsável possa
configurar limites para uma conta supervisionada. A interface deverá informar à
pessoa supervisionada quando controles estiverem ativos e quais categorias de
controle são aplicadas, observadas as restrições de segurança e privacidade.

Não se presume que o administrador técnico seja necessariamente pai, mãe ou
responsável legal. A forma de comprovação ou declaração dessa qualidade constitui
questão submetida ao parecer.

## 5. Situação atual quanto a dados pessoais

O desenho em avaliação privilegia operação local e minimização de dados. O Lyra
não pretende coletar documentos de identidade, imagens faciais, biometria,
histórico de navegação ou localização para implementar supervisão parental.

Não há decisão de contratar serviço de aferição de idade. Também não há decisão
de tratar data de nascimento, autodeclaração, declaração parental ou tipo da
conta como mecanismo juridicamente suficiente. Qualquer implementação dependerá
da definição do escopo legal, finalidade, base jurídica, necessidade,
proporcionalidade, retenção, segurança, contestação e descarte.

Caso seja necessário manter estado local, pretende-se armazenar somente os
atributos indispensáveis à aplicação da política, protegidos contra leitura ou
alteração por contas não autorizadas. A eventual API para aplicativos deverá
responder apenas o mínimo necessário para uma finalidade autorizada, sem expor
data de nascimento, documento ou histórico de consultas de forma irrestrita.

## 6. Funcionalidades em avaliação

As seguintes funcionalidades são possibilidades técnicas, e não decisões de
conformidade ou compromissos definitivos:

- associação entre responsável e conta supervisionada;
- autorização expressa para instalação de aplicativos;
- restrições baseadas em classificação indicativa ou categorias de conteúdo;
- limites e informações consolidadas de tempo de uso;
- aviso visível de supervisão ativa;
- pedidos de autorização, contestação e revisão;
- recuperação segura em caso de perda das credenciais do responsável;
- sinal mínimo de idade ou limiar fornecido somente a consumidores autorizados;
- registros locais mínimos de alterações administrativas e decisões de acesso.

O projeto não pretende registrar conteúdo de comunicações, capturas de tela,
teclas digitadas, áudio, vídeo, localização ou histórico detalhado de navegação
como parte dessas funcionalidades.

## 7. Premissas de segurança e produto

As proteções devem continuar vigentes quando a interface gráfica estiver
fechada. Falhas, atualizações incompletas, estado corrompido ou ausência de uma
resposta externa não devem produzir liberação silenciosa de acesso. Operações
privilegiadas devem ser restritas, autenticadas e auditáveis na medida necessária.

O produto é concebido para funcionamento também offline. O parecer deverá
avaliar como conciliar essa característica com eventuais obrigações de aferição,
consentimento, revogação, atualização de políticas e interoperabilidade.

## 8. Limites desta descrição

Este documento não define quem é fornecedor, controlador ou operador; não
conclui que o Vega seja ou não loja de aplicações; não atribui responsabilidades
a terceiros; e não afirma conformidade com o ECA Digital ou com a LGPD.

As conclusões deverão considerar a forma concreta de disponibilização do Lyra,
os territórios alcançados, os agentes responsáveis, os termos aplicáveis e as
normas vigentes na data de emissão do parecer.

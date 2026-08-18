# Anexo técnico de privacidade e segurança

**Produto:** Lyra OS e Vega

**Data de referência:** 18 de agosto de 2026

**Finalidade:** apresentar o desenho técnico considerado, sujeito ao parecer

## 1. Princípios de projeto

O desenho em avaliação segue os princípios de minimização, proteção por padrão,
separação de privilégios, transparência, funcionamento local, recuperação segura
e baixa necessidade de manutenção. Nenhuma solução de aferição etária foi
selecionada.

As funcionalidades descritas são propostas técnicas. Sua presença neste anexo
não significa que sejam suficientes, obrigatórias ou juridicamente aprovadas.

## 2. Separação de componentes

O Vega atua como interface de configuração. Um serviço de sistema separado seria
responsável por persistir e aplicar políticas que exijam privilégio. Adaptadores
específicos fariam a integração com contas locais, instalação de software e
eventuais componentes maduros da base openSUSE.

Essa separação pretende assegurar que:

- fechar ou interromper a interface não desative as políticas;
- a interface não obtenha acesso direto e amplo a dados sensíveis;
- cada operação privilegiada tenha autorização explícita e finalidade definida;
- componentes possam ser atualizados ou revertidos com limites claros;
- a política seja aplicada de maneira uniforme aos canais tecnicamente cobertos.

## 3. Papéis funcionais propostos

O modelo considera, sem presumir sua qualificação jurídica:

- administrador técnico do equipamento;
- pessoa que demonstre legitimidade para atuar como responsável;
- pessoa usuária de conta supervisionada;
- serviço local de políticas;
- interface Vega;
- gerenciadores de pacotes e catálogos de aplicativos;
- aplicativo autorizado a solicitar resposta etária mínima.

Administração técnica e responsabilidade legal não são consideradas equivalentes
por padrão. O vínculo, sua criação, contestação, alteração e encerramento dependem
de orientação jurídica.

## 4. Dados potencialmente necessários

O estado local cogitado contém apenas identificadores técnicos de contas,
vínculos de supervisão, política aplicável, decisões de autorização, versão do
esquema e registros mínimos para integridade e recuperação.

O projeto busca evitar a coleta ou o armazenamento de:

- documento civil ou cópia documental;
- imagem facial, modelo biométrico ou gravação de vídeo;
- data de nascimento quando um atributo menos preciso for suficiente;
- conteúdo de mensagens, áudio, tela ou teclas digitadas;
- localização ou histórico detalhado de navegação;
- inventário de consultas etárias acessível a aplicativos;
- dados usados para publicidade, recomendação ou perfilamento comercial.

O parecer deverá determinar quais dados são realmente necessários e autorizados.

## 5. Resposta etária mínima

Caso a legislação exija o fornecimento de sinal a aplicativos, a arquitetura
pretende evitar a exposição de idade exata. Uma solicitação deveria declarar
finalidade e limiar necessários, ser autenticada e receber somente uma resposta
restrita, como permitido, negado, indisponível ou contestado.

O desenho deve impedir consultas arbitrárias, enumeração de faixas, correlação
entre aplicações e compartilhamento contínuo. A eventual origem da informação,
seu grau de confiança, a necessidade de consentimento e as regras de auditoria
dependem do parecer e da regulamentação aplicável.

## 6. Instalação de aplicativos

Antes de uma instalação solicitada por conta supervisionada, pretende-se avaliar
a política aplicável e a classificação disponível. Quando necessária, a decisão
do responsável deve ser expressa e associada ao pedido concreto, sem autorização
presumida pela ausência de resposta.

Devem ser avaliados possíveis caminhos alternativos, como linha de comando,
outras interfaces, pacotes locais e múltiplas origens. A solução não deve alegar
cobertura que não consiga aplicar tecnicamente.

Metadados ausentes, ambíguos ou inválidos não devem resultar automaticamente em
classificação adulta ou liberação irrestrita. O comportamento correto em cada
caso é quesito jurídico e de segurança.

## 7. Tempo de uso e transparência

As métricas consideradas são consolidadas e limitadas ao necessário para a
finalidade definida. A interface deverá explicar o que é medido, por quanto tempo,
quem pode consultar e quais limitações técnicas existem.

A pessoa supervisionada deverá receber aviso claro quando a supervisão estiver
ativa e conhecer as categorias de controle aplicadas. O desenho contempla meios
de solicitar autorização, contestar erro e obter revisão apropriada à idade e à
capacidade da pessoa usuária.

## 8. Persistência, acesso e retenção

O estado privilegiado deve ser armazenado com acesso restrito, escrita atômica,
validação de integridade e versão de formato. Cópias de segurança devem manter as
mesmas proteções. Logs não devem conter documentos, segredos, caminhos pessoais
desnecessários ou conteúdo de atividade supervisionada.

Prazos de retenção e descarte ainda não foram definidos. O parecer deverá indicar
critérios por categoria de dado, inclusive para revogação, maioridade, exclusão
da conta, reinstalação do sistema e restauração de backup.

## 9. Falhas e recuperação

O sistema deve distinguir ausência de configuração, estado corrompido, serviço
indisponível e decisão de acesso. Nenhuma dessas condições deve ser silenciosamente
convertida em idade adulta ou autorização ampla.

A recuperação de credenciais não deve permitir que uma conta supervisionada
remova os próprios limites. Ao mesmo tempo, deve existir procedimento legítimo
para perda de credenciais, mudança de responsável, contestação e encerramento da
supervisão, sem retenção indefinida.

## 10. Ameaças consideradas

O desenvolvimento deverá considerar, no mínimo:

- conta local tentando elevar privilégios ou alterar o estado;
- aplicativo tentando consultar atributos além da finalidade autorizada;
- responsável ou administrador utilizando a função para vigilância excessiva;
- metadados de aplicativo ausentes, falsos ou manipulados;
- alteração de relógio, downgrade, corrupção ou restauração de estado antigo;
- canal de instalação que contorne a verificação comum;
- indisponibilidade de rede ou de provedor externo;
- exposição de dados em logs, backups, relatórios ou interfaces de sistema.

## 11. Decisões dependentes do parecer

Permanecem abertas, entre outras, as seguintes decisões:

- enquadramento e responsabilidades de cada agente;
- necessidade, método e grau de confiança da aferição de idade;
- comprovação da legitimidade do responsável;
- bases legais e dados mínimos de cada fluxo;
- conteúdo e retenção de registros;
- extensão da API e consumidores autorizados;
- comportamento em modo offline, ausência de sinal e contestação;
- documentos de transparência e procedimentos de direitos;
- requisitos mínimos para disponibilização pública.

# Lyra OS Kickstart - Fedora Base

# Instalação em modo texto
text
reboot

# Idioma e Teclado
lang pt_BR.UTF-8
keyboard br-abnt2

# Configuração de Rede (usar NetworkManager no sistema final)
network --bootproto=dhcp --device=link --activate

# Repositórios (serão ajustados conforme a versão)
url --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-$releasever&arch=$basearch

# Autenticação
rootpw --plaintext lyra
firewall --disabled
selinux --enforcing
timezone America/Sao_Paulo

# Particionamento (o Anaconda vai lidar com isso no instalador)
clearpart --all --initlabel
autopart

# Seleção de Pacotes (Minimizando para o GNOME Vanilla)
%packages
@gnome-desktop
gnome-terminal
nautilus
NetworkManager
# Adicionar outras ferramentas básicas aqui
%end

# Pós-instalação
%post
# Exemplo: Criar branding simples
echo "Lyra OS" > /etc/issue
echo "Bem-vindo ao Lyra OS" >> /etc/issue
%end

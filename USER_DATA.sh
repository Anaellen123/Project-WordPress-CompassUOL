#!/bin/bash

# Atualiza os pacotes do sistema
echo "Atualizando pacotes do sistema..."
apt-get update -y && apt-get upgrade -y

# Instala pacotes necessários
echo "Instalando pacotes necessários..."
apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# Adiciona a chave GPG oficial do Docker
echo "Adicionando a chave GPG oficial do Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Adiciona o repositório do Docker
echo "Adicionando o repositório do Docker..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Atualiza novamente os pacotes para incluir o repositório do Docker
echo "Atualizando lista de pacotes com o repositório do Docker..."
apt-get update -y

# Instala o Docker e seus componentes
echo "Instalando Docker CE e plugins..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Inicia e habilita o serviço Docker
echo "Iniciando e habilitando o serviço Docker..."
systemctl start docker
systemctl enable docker

# Adiciona o usuário 'ubuntu' ao grupo docker
echo "Adicionando o usuário 'ubuntu' ao grupo Docker..."
usermod -aG docker ubuntu

# Instala o cliente MySQL
echo "Instalando cliente MySQL..."
apt-get install -y mysql-client-core-8.0

# Configuração do EFS
echo "Configurando sistema de arquivos EFS..."
mkdir -p /mnt/efs
apt-get install -y nfs-common
mount -t nfs4 -o rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport <DNS_NAME_DO_EFS>:/ /mnt/efs

# Cria o diretório onde o arquivo docker-compose.yaml será salvo
echo "Criando diretório para o arquivo docker-compose.yaml..."
mkdir -p /home/ubuntu/myapp

# Cria o arquivo docker-compose.yaml
echo "Criando o arquivo docker-compose.yaml..."
cat > /home/ubuntu/myapp/docker-compose.yaml <<EOL
version: '3.8'

services:
  wordpress:
    image: wordpress:latest
    restart: always
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: <endpoint_do_RDS>
      WORDPRESS_DB_NAME: <nome_do_banco_de_dados_criado_no_RDS>
      WORDPRESS_DB_USER: <user_criado_no_RDS>
      WORDPRESS_DB_PASSWORD: <senha_criada_no_RDS>
    volumes:
      - /mnt/efs/efs_wordpress:/var/www/html
EOL

# Altera permissões no diretório do projeto
chown -R ubuntu:ubuntu /home/ubuntu/myapp

# Inicia o Docker Compose
echo "Iniciando o Docker Compose..."
cd /home/ubuntu/myapp
docker compose up -d

# Mensagem final
echo "Concluído! O ambiente Docker Compose foi iniciado."

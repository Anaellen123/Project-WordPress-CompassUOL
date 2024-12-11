# Projeto WordPress
O objetivo deste projeto é provisionar uma instância EC2 que, por meio de um script `user_data`, realizará a instalação do Docker e configurará o ambiente necessário para o WordPress. O projeto inclui a criação de um arquivo Docker Compose, responsável pelo deploy do WordPress, integrado a um banco de dados RDS (AWS) e utilizando o EFS para o armazenamento de arquivos estáticos da aplicação. Além disso, será configurado um balanceador de carga (Load Balancer) para gerenciar o tráfego e garantir a alta disponibilidade do WordPress.

## Sumário
- [Pré-requisitos](#pré-requisitos)
- [O que é uma VPC](#o-que-é-uma-vpc)
- [Como criar uma VPC](#como-criar-uma-vpc)
  - [NAT Gateway](#nat-gateway)
  - [Criando um IP Elástico](#criando-um-ip-elástico)
  - [Conectando o NAT Gateway à sub-rede privada da sua VPC](#conectando-o-nat-gateway-à-sub-rede-privada-da-sua-vpc)
- [Security Group](#criando-security-group)
   - [Security Group para o Load Balancer](#security-group-para-o-load-balancer)
   - [Security Group para o EFS](#security-group-para-o-efs)
   - [Security Group para o RDS](#security-group-para-o-rds)
   - [Security Group para a instância privada](#security-group-para-a-instância-privada)
  - [Security Group para a instância Bastion Host](#security-group-para-a-instância-bastion-host)
- [RDS](#rds)
- [Criando um RDS](#criando-um-rds)
- [EFS](#efs)
- [Criando um EFS](#criando-um-efss)
- [Launch Template](#launch-template)
- [Criando um Launch Template](#criando-um-launch-template)
    - [Key pair](#key-pair)
    - [Criando a instância privada](#criando-a-instância-privada)
- [Bastion Host](#bastion-host)
- [Criando sua instância Bastion Host](#criando-sua-instância-bastion-host)
      

---

## Pré-requisitos:
* Ter conhecimento básico em Docker
* Ter acesso à AWS
* Ter conhecimento básico em AWS e WordPress

---

## O que é uma VPC?

Uma VPC (Virtual Private Cloud) é uma rede virtual isolada dentro da infraestrutura de uma nuvem pública, como a AWS. Ela permite que você configure e controle um ambiente de rede, incluindo sub-redes, tabelas de rotas, gateways de internet e políticas de segurança, de maneira similar a um data center tradicional. Isso oferece flexibilidade para hospedar recursos com segurança, controlando o acesso e a conectividade interna e externa.

---

## Como criar uma VPC:
1. Acesse sua conta AWS.
2. No painel principal, procure por "**VPC**" na barra de pesquisa e clique na opção **VPC**.
3. No painel lateral esquerdo, clique em **Your VPCs**.
4. Clique em **Create VPC**.
5. Preencha os campos necessários:
   - **5.1** - Marque a opção **VPC and more**. Assim que selecionar esta opção, aparecerá um painel com um modelo de VPC contendo 4 subnets para 2 zonas de disponibilidade.
   - **5.2** - Em **Auto-generate**, dê um nome *exemplo: Newvpc*
   - **5.3** - Em **IPv4 CIDR block**, deixe a opção de IP como `10.0.0.0/16`.
   - **5.4** - Mais abaixo, haverá a opção **Customize subnets CIDR blocks**. Clique nela e substitua o final da máscara de rede por `/24` (exemplo: `*.*.*.*/24`).
6. Pronto, clique em **Create VPC** para finalizar a criação de sua VPC.

---

### NAT Gateway
Um **NAT Gateway** é um serviço da AWS que permite que instâncias em sub-redes privadas acessem a Internet de forma segura, sem expor essas instâncias diretamente à Internet pública. Ele realiza a tradução de endereços IP privados para públicos para tráfego de saída (**outbound**), garantindo que o tráfego de entrada (**inbound**) da Internet seja bloqueado, aumentando a segurança. Para a criação do NAT Gateway, é necessário primeiro obter um IP elástico. Siga as instruções abaixo.

### Criando um IP Elástico:
1. Na aba de VPC, vá na opção **Elastic IPs**.
2. Clique em **Allocate Elastic IP address**.
3. Na seção **Public IPv4 address pool**, deixe marcada a opção **Amazon's pool of IPv4 addresses**.
4. Na seção **Network border group**, selecione a região **us-east-1**.
5. Clique em **Allocate** para finalizar a criação do seu IP elástico.

#### ***Após termos criado o seu IP elástico, vamos para a criação do NAT Gateway.***

### Criando um NAT Gateway:
1. Na aba de VPC, vá na opção **NAT gateways**.
2. Clique na opção **Create NAT gateway**.
3. Na opção **Name - optional**, dê um nome para o seu NAT Gateway.
4. Na opção **Subnet**, selecione uma sub-rede pública da VPC que você criou.
5. Clique em **Create NAT gateway** e o seu NAT Gateway estará criado.

### Conectando o NAT Gateway à sub-rede privada da sua VPC:
1. Ainda na aba de VPC, vá na opção **Your VPCs**.
2. No **Resource map**, onde é exibido o mapa das suas sub-redes, selecione uma sub-rede privada. Clique no ícone de seta ao lado de **Route tables**.
3. Na aba da **Route table** correspondente, desça até a seção **Routes** e clique em **Edit routes**.
4. Clique na opção **Add route**:
   - Em **Destination**, insira o IP `0.0.0.0/0`.
   - Em **Target**, selecione a opção **NAT Gateway** e escolha o NAT Gateway que você criou.
5. Clique em **Save changes**. Pronto! A conexão do NAT Gateway com sua sub-rede privada foi configurada com sucesso.

---

## Criando um Security Group
1. No painel de EC2, acesse a seção **Network & Security** e clique em **Security Groups**.
2. Na página **Security Groups**, clique em **Create security group** para iniciar a configuração.

---

## Security Group para o Load Balancer
### 1. Configuração Básica (*Basic details*)
- **Security group name**: Dê um nome, por exemplo: `SG-LoadBalancer`.
- **Description**: Insira uma breve descrição sobre o propósito do Security Group.
- **VPC**: Selecione a VPC criada anteriormente.

### 2. Regras de Entrada (*Inbound rules*)
#### Adicione as seguintes regras:
1. **Regra 1**:
   - **Type**: HTTP  
   - **Protocol**: TCP  
   - **Port range**: 80  
   - **Source type**: Anywhere-IPv4  
   - **Source**: `0.0.0.0/0`  
   - **Description (opcional)**: Permite tráfego HTTP para o Load Balancer.

2. **Regra 2**:
   - **Type**: HTTPS  
   - **Protocol**: TCP  
   - **Port range**: 443  
   - **Source type**: Anywhere-IPv4  
   - **Source**: `0.0.0.0/0`  
   - **Description (opcional)**: Permite tráfego HTTPS para o Load Balancer.

### 3. Regras de Saída (*Outbound rules*)
- Por padrão, uma regra de saída já está configurada com os seguintes valores:
  - **Type**: All traffic  
  - **Protocol**: All  
  - **Port range**: All  
  - **Destination**: `0.0.0.0/0`.  

### 4. Finalização
Clique em **Create security group** para concluir a configuração.

---

## Security Group para o EFS
### 1. Configuração Básica (*Basic details*)
- **Security group name**: Insira um nome, por exemplo: `SG-EFS`.
- **Description**: Descreva brevemente o propósito do Security Group.
- **VPC**: Selecione a VPC criada anteriormente.

### 2. Regras de Entrada (*Inbound rules*)
#### Adicione as seguintes regras:
1. **Regra 1**:
   - **Type**: NFS  
   - **Protocol**: TCP  
   - **Port range**: 2049  
   - **Source type**: Custom  
   - **Source**: IP da sua *subnet* privada na zona `us-east-1a`.  
   - **Description (opcional)**: Permite tráfego para o EFS na região `us-east-1a`.

2. **Regra 2**:
   - **Type**: NFS  
   - **Protocol**: TCP  
   - **Port range**: 2049  
   - **Source type**: Custom  
   - **Source**: IP da sua *subnet* privada na zona `us-east-1b`.  
   - **Description (opcional)**: Permite tráfego para o EFS na região `us-east-1b`.

### 3. Regras de Saída (*Outbound rules*)
- Por padrão, uma regra de saída já está configurada com os seguintes valores:
  - **Type**: All traffic  
  - **Protocol**: All  
  - **Port range**: All  
  - **Destination**: `0.0.0.0/0`.  

### 4. Finalização
Clique em **Create security group** para concluir a configuração.

---

## Security Group para o RDS
### 1. Configuração Básica (*Basic details*)
- **Security group name**: Insira um nome, por exemplo: `SG-RDS`.
- **Description**: Descreva brevemente o propósito do Security Group.
- **VPC**: Selecione a VPC criada anteriormente.

### 2. Regras de Entrada (*Inbound rules*)
#### Adicione as seguintes regras:
1. **Regra 1**:
   - **Type**: MYSQL/Aurora 
   - **Protocol**: TCP  
   - **Port range**: 3306
   - **Source type**: Custom  
   - **Source**: IP da sua *subnet* privada na zona `us-east-1a`.  
   - **Description (opcional)**: Permite tráfego para o RDS na região `us-east-1a`.

2. **Regra 2**:
   - **Type**: MYSQL/Aurora
   - **Protocol**: TCP  
   - **Port range**: 3306
   - **Source type**: Custom  
   - **Source**: IP da sua *subnet* privada na zona `us-east-1b`.  
   - **Description (opcional)**: Permite tráfego para o RDS na região `us-east-1b`.

### 3. Regras de Saída (*Outbound rules*)
- Por padrão, uma regra de saída já está configurada com os seguintes valores:
  - **Type**: All traffic  
  - **Protocol**: All  
  - **Port range**: All  
  - **Destination**: `0.0.0.0/0`.  

### 4. Finalização
Clique em **Create security group** para concluir a configuração.

---

## Security Group para a Instância Privada

### 1. Configuração Básica (*Basic details*)
- **Security group name**: Insira um nome, por exemplo: `SG-InstancePrivada`.
- **Description**: Adicione uma descrição sobre o propósito do Security Group.
- **VPC**: Selecione a VPC criada anteriormente.

---

### 2. Regras de Entrada (*Inbound rules*)

#### Adicione as seguintes regras:

1. **Regra 1**:  
   - **Type**: SSH  
   - **Protocol**: TCP  
   - **Port range**: 22  
   - **Source type**: Custom  
   - **Source**: `*.*.*.*/16` (IPv4 CIDR da sua VPC)  
   - **Description (opcional)**: Permite acesso SSH à instância privada através da Bastion Host.

2. **Regra 2**:  
   - **Type**: HTTP  
   - **Protocol**: TCP  
   - **Port range**: 80  
   - **Source type**: Custom  
   - **Source**: `SG-LoadBalancer`  
     > **Nota**: Clique no ícone de lupa e utilize o scroll lateral para localizar e selecionar o Security Group já criado para o Load Balancer.  
   - **Description (opcional)**: Permite tráfego HTTP originado pelo Load Balancer.

3. **Regra 3**:  
   - **Type**: HTTPS  
   - **Protocol**: TCP  
   - **Port range**: 443  
   - **Source type**: Custom  
   - **Source**: `SG-LoadBalancer`  
     > **Nota**: Clique no ícone de lupa e utilize o scroll lateral para localizar e selecionar o Security Group já criado para o Load Balancer.  
   - **Description (opcional)**: Permite tráfego HTTPS originado pelo Load Balancer.

4. **Regra 4**:  
   - **Type**: NFS  
   - **Protocol**: TCP  
   - **Port range**: 2049  
   - **Source type**: Custom  
   - **Source**: `SG-EFS`  
     > **Nota**: Clique no ícone de lupa e utilize o scroll lateral para localizar e selecionar o Security Group já criado para o EFS.  
   - **Description (opcional)**: Permite o acesso privado ao EFS.

5. **Regra 5**:  
   - **Type**: MYSQL/Aurora  
   - **Protocol**: TCP  
   - **Port range**: 3306  
   - **Source type**: Custom  
   - **Source**: `SG-RDS`  
     > **Nota**: Clique no ícone de lupa e utilize o scroll lateral para localizar e selecionar o Security Group já criado para o RDS.  
   - **Description (opcional)**: Permite o acesso privado ao RDS.

---

### 3. Regras de Saída (*Outbound rules*)
- Por padrão, uma regra de saída já está configurada com os seguintes valores:
  - **Type**: All traffic  
  - **Protocol**: All  
  - **Port range**: All  
  - **Destination**: `0.0.0.0/0`.

---

### 4. Finalização
Clique em **Create security group** para concluir a configuração.


---
## Security Group para a instância Bastion Host
### 1. Configuração Básica (*Basic details*)
- **Security group name**: Dê um nome, por exemplo: `SG-BastionHost`.
- **Description**: Adicione uma descrição sobre o propósito do Security Group.
- **VPC**: Selecione a VPC criada anteriormente.

### 2. Regras de Entrada (*Inbound rules*)
#### Adicione a seguinte regra:
1. **Regra 1**:
   - **Type**: SSH  
   - **Protocol**: TCP  
   - **Port range**: 22  
   - **Source type**: Anywhere-IPv4  
   - **Source**: `0.0.0.0/0`  
   - **Description (opcional)**: Permite acesso SSH para a instância Bastion Host.

### 3. Regras de Saída (*Outbound rules*)
- Por padrão, uma regra de saída já está configurada com os seguintes valores:
  - **Type**: All traffic  
  - **Protocol**: All  
  - **Port range**: All  
  - **Destination**: `0.0.0.0/0`.  

### 4. Finalização
Clique em **Create security group** para concluir a configuração.

---

## RDS (*Relational Database Service*)
O Amazon RDS (Relational Database Service) é um serviço gerenciado de banco de dados relacional fornecido pela AWS. Ele simplifica o processo de configuração, operação e escalabilidade de bancos de dados na nuvem, eliminando a necessidade de gerenciar hardware e reduzindo o tempo necessário para tarefas administrativas comuns.

> **Banco de dados relacional:** Um banco de dados relacional é um sistema de armazenamento e gerenciamento de dados baseado no modelo relacional, que organiza as informações em tabelas (também chamadas de relações).

## Criando um RDS:
1. Vá na aba RDS, em **Amazon RDS** clique em **Databases**.
2. Após acessar a área de **Databases**, clique em **Create database** para iniciarmos a criação do seu **RDS**.
3. Em **Choose a database creation method**, deixe selecionada a opção **Standard create**.
4. Em **Engine options**, selecione **MySQL**.
5. Na opção **Templates**, selecione a opção **Free tier**.
6. Na opção **Settings**:
   - Em **DB instance identifier**, aparecerá um nome padrão como *database-1*. Você pode alterar esse nome caso queira, ou mantê-lo como está.
   - Em **Master username**, aparece um nome padrão do seu usuário como *admin*. Você pode alterá-lo, caso deseje, ou mantê-lo.
7. Em **Credentials management**, deixe selecionada a opção **Self managed**.
8. Em **Master password**, crie uma senha.
9. Em **Confirm master password**, digite a senha criada para confirmar.
10. Na opção **Instance configuration**, selecione **Burstable classes (includes t classes)**.
11. Ainda na opção **Instance configuration**, aparecerá por padrão **db.t4g.micro**. Altere para **db.t3.micro**.
12. Na opção **Connectivity**:
    - Em **Compute resource**, deixe selecionada a opção **Don’t connect to an EC2 compute resource**.
    - Em **Virtual private cloud (VPC)**, selecione a VPC criada previamente.
    - Em **Public access**, deixe marcada a opção **No**.
    - Em **VPC security group (firewall)**, selecione a opção **Choose existing**.
    - Em **Existing VPC security groups**, selecione o Security Group criado para o seu RDS.
    - Em **Availability Zone**, deixe selecionada a opção **No preference**.
13. Em **Additional configuration**:
    - Na seção **Database options**, em **Initial database name**, forneça o nome do seu banco de dados. Exemplo: *wordpressdb*.
14. Clique em **Create database** para finalizar a criação do RDS.

**Observação:** *O RDS pode demorar alguns minutos para ser criado.*

---
## EFS (*Elastic File System*)
O Amazon Elastic File System (EFS) é um serviço de armazenamento de arquivos na nuvem da AWS, projetado para fornecer armazenamento elástico, altamente disponível e escalável. Ele é ideal para cargas de trabalho que exigem acesso compartilhado a arquivos, permitindo que múltiplas instâncias acessem o sistema de arquivos simultaneamente. Neste projeto, o EFS será utilizado para montar o diretório onde os arquivos estáticos do WordPress serão armazenados, proporcionando alta disponibilidade e escalabilidade para esses arquivos.
    
## Criando um EFS:
1. Na aba **EFS**, será exibido o painel do **Amazon EFS**.
2. Clique em **Create file system** para iniciar a criação do **EFS**.
3. Após clicar, aparecerá uma pequena aba. Nas opções inferiores, clique em **Customize**.
4. Será exibida a aba **File systems**.
5. Em **File system settings**, na seção **General**:
   - Em **Name - optional**, dê um nome ao seu **EFS** (exemplo: `testingEFS`).
   - Em **File system type**, deixe a opção **Regional** selecionada.
6. Avance para a próxima tela clicando em **Next**.
7. Você será direcionado para a aba **Network access**:
   - Em **Virtual Private Cloud (VPC)**, selecione a VPC que criamos.
   - Na seção **Mount targets**, substitua o **Security group** padrão pelo **Security Group** que criamos para o seu **EFS**.
8. Avance clicando em **Next** e continue clicando em **Next** até chegar na aba **Review and create**.
9. Revise as configurações e clique em **Create** para finalizar a criação do seu **EFS**.

**Observação**: *O EFS pode demorar alguns minutos para ser criado.*

---


## Launch Template
Um Launch Template na AWS é uma maneira de definir e armazenar uma configuração padrão para lançar instâncias EC2. Ele contém parâmetros como a imagem do sistema operacional (AMI), tipo de instância, configurações de rede, volumes de armazenamento, chaves SSH e outras opções de configuração. O Launch Template permite criar instâncias EC2 com as mesmas configurações repetidamente, proporcionando consistência e eficiência no gerenciamento de infraestruturas, especialmente em ambientes com escalabilidade automática (Auto Scaling).

## Criando um Launch Template:
1. Na aba **EC2**, vá nas opções de **Instances** e clique em **Launch Templates**.
2. Clique na opção **Create launch template**.
3. Em **Launch template name and description**, preencha:
   - Em **Launch template name - required**, dê um nome ao seu template (exemplo: `MyTemplate`).
   - Em **Template version description**, coloque a versão do seu template (exemplo: `version-1`).
4. Em **Template version description**, clique em **Quick Start** e selecione a opção **Ubuntu**.
   
   **Observação**: *Para seguir esses passos, você terá que ter acesso a um terminal **Ubuntu**.*
   
5. Em **Instance type**, selecione a opção **t2.micro**.
6. Em **Key pair (login)**, clique no link *create new key pair*.

    #### Key pair
    Aparecerá uma pequena aba para criarmos uma chave de acesso, necessária para a conexão SSH no terminal:
   - Em **Key pair name**, dê um nome à sua chave (exemplo: `chave1`).
   - Em **Key pair type**, selecione **ED25519**.
   - Em **Private key file format**, deixe selecionado o formato **.pem**.
   - Clique em **Create key pair**. Ao clicar, será criada a chave e baixado um arquivo `.pem` em sua máquina (exemplo de nome: `chave1.pem`).

7. Em **Key pair name**, selecione a chave que você criou.
8. Em **Network settings**:
   - Em **Subnet**, selecione a subnet privada da VPC que criamos (exemplo: `Newvpc-subnet-private1-us-east-1a`).
   - Em **Firewall (security groups)**, deixe selecionada a opção **Select existing security group**.
   - Em **Common security groups**, selecione o grupo de segurança que criamos para sua instância privada.
   - Em **Advanced network configuration**, procure pela opção **Auto-assign public IP** e defina como **Disable**.

9. Na aba **Resource tags**, adicione suas tags caso esteja utilizando o AWS com credenciais específicas.
10. Na aba **Advanced details**, role a tela até o final e procure por **User data - optional**.
11. Dentro do **User Data - optional** adicione o seguinte conteúdo:

```bash
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
mount -t nfs4 -o rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport <DNS name do seu EFS>:/ /mnt/efs

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
      WORDPRESS_DB_HOST: <endpoint do seu RDS>:3306
      WORDPRESS_DB_NAME: <Nome do banco de dados criado na configuração do RDS>
      WORDPRESS_DB_USER: <user criado na configuração do RDS>
      WORDPRESS_DB_PASSWORD: <senha criada na configuração do RDS>
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

12. Pronto, clique em **Create lauch template** para finalizarmos a criação do seu template


## Criando a instância privada:
1. Ainda na aba **Launch Templates** selecione seu template já criado.
2. Vá em **Actions** e clica na opção **Launch instance from template**
3. Só clicar na opção **Lauch instance** e sua instancia será criada automaticamente.
 **Observação**: *A inicialização da instancia pode demorar alguns minutos.*

##Bastion Host
A Bastion Host é uma instância de servidor que atua como um ponto de acesso seguro para acessar outros recursos em uma rede privada. Geralmente, ela é configurada em uma sub-rede pública e serve como intermediária para conexões SSH ou RDP, permitindo o acesso a servidores em sub-redes privadas. Sua principal função é fornecer uma camada extra de segurança, pois as instâncias privadas não são acessíveis diretamente da internet, sendo acessadas apenas através da Bastion Host.

## Criando sua instância Bastion Host


 
   


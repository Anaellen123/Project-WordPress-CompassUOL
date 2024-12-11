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
   - **5.2** - Em **Auto-generate**, dê um nome.
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








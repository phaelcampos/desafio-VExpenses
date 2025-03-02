# Documentação da Infraestrutura AWS com Terraform

## Relações entre os Recursos Criados

A infraestrutura definida no código Terraform é um sistema integrado de componentes que trabalham em conjunto para implantar uma instância EC2 segura e funcional na AWS.

---

### 1. Provedor AWS e variáveis:

-   **Provedor AWS (`provider "aws"`)**
    -   **Descrição:** Configura o ambiente para criação de recursos na região `us-east-1` da AWS. Define as credenciais e a região onde todos os recursos subsequentes serão criados. Todos os recursos (VPC, EC2, Security Groups) dependem dessa configuração regional para funcionar corretamente.
- **Variáveis (`projeto` e `candidato`)**
    - `var.projeto`: Define o prefixo "VExpenses" nos nomes dos recursos.
    - `var.candidato`: Adiciona um identificador único (ex: "SeuNome").
  ```hcl
  tags = {
    Name = "${var.projeto}-${var.candidato}-vpc"
  }

### 2. Chave SSH:

-   `tls_private_key`
    -   **Descrição:** Gera um par de chaves SSH (privada e pública) localmente. A chave privada é usada para acessar a instância EC2, enquanto a chave pública é registrada na AWS.
-   `aws_key_pair`
    -   **Descrição:** Registra a chave pública gerada localmente na AWS. Isso permite que a instância EC2 seja acessada usando a chave privada correspondente.

    ```hcl
    resource "aws_key_pair" "ec2_key_pair" {
      key_name   = "${var.projeto}-${var.candidato}-key"
      public_key = tls_private_key.ec2_key.public_key_openssh
    }
    ```

### 3. Rede:

-   **VPC (aws_vpc)**
    -   **Descrição:** Cria uma VPC, que é uma rede virtual isolada na AWS. Define o espaço de endereçamento IP (10.0.0.0/16) para a rede.
    -   **Funcionalidades:**
        -   `enable_dns_support`: Habilita a resolução de nomes DNS dentro da VPC.
        -   `enable_dns_hostnames`: Atribui nomes de host automaticamente às instâncias EC2 na VPC.
-   **Subnet (aws_subnet)**
    -   **Descrição:** Cria uma sub-rede pública (10.0.1.0/24) dentro da VPC, na zona de disponibilidade `us-east-1a`. As instâncias EC2 são lançadas nesta sub-rede.
-   **Internet Gateway (aws_internet_gateway)**
    -   **Descrição:** Permite que a VPC se comunique com a internet. Atua como um roteador para o tráfego de entrada e saída da VPC.

    ```hcl
    resource "aws_internet_gateway" "main_igw" {
      vpc_id = aws_vpc.main_vpc.id
    }
    ```

-   **Tabela de rotas e associação**
    -   **Descrição:** A tabela de rotas define como o tráfego é direcionado dentro da VPC. Uma rota padrão é criada para direcionar o tráfego de saída para o Internet Gateway. A tabela de rotas é associada à sub-rede, permitindo que as instâncias EC2 na sub-rede se comuniquem com a internet.

### 4. Segurança:

-   **Security Group (aws_security_group)**
    -   **Descrição:** Atua como um firewall virtual para as instâncias EC2, controlando o tráfego de entrada e saída.
    -   **Regras de Entrada:**
        -   Permite o tráfego SSH (porta 22) de qualquer endereço IP (0.0.0.0/0), permitindo acesso remoto à instância.

    ```hcl
    ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
    ```

    -   **Regras de saída:**
        -   Permite todo o tráfego de saída da instância para qualquer destino (0.0.0.0/0), permitindo que a instância acesse a internet.

    ```hcl
    egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
    ```

### 5. Instância EC2:

-   **AMI (data.aws_ami)**
    -   **Descrição:** Busca a AMI mais recente do Debian 12. A AMI define o sistema operacional e o software pré-instalado na instância EC2.

    ```hcl
    data "aws_ami" "debian12" {
      filter {
        name   = "name"
        values = ["debian-12-amd64-*"]
      }
    }
    ```

-   **Configuração da instância (aws_instance)**
    -   **Descrição:** Define as configurações da instância EC2, como tipo de instância (t2.micro), sub-rede, grupo de segurança e script de inicialização (user data).

    ```hcl
    resource "aws_instance" "debian_ec2" {
      ami             = data.aws_ami.debian12.id
      instance_type   = "t2.micro"
      subnet_id       = aws_subnet.main_subnet.id
      security_groups = [aws_security_group.main_sg.name]
      user_data       = <<-EOF
        #!/bin/bash
        apt-get update -y
        apt-get upgrade -y
      EOF
    }
    ```
### 6. Outputs:

-   **Chave privada**
    -   **Descrição:** Exibe a chave privada SSH gerada localmente.
    -   **`sensitive = true`:** Marca a saída como sensível, impedindo que ela seja exibida no console do Terraform, a menos que explicitamente solicitado.
    -   **Importante:** Esta saída deve ser armazenada em um local seguro, como um gerenciador de segredos, e não deve ser compartilhada publicamente.

    ```hcl
    output "private_key" {
      value     = tls_private_key.ec2_key.private_key_pem
      sensitive = true
    }
    ```

-   **IP público da EC2**
    -   **Descrição:** Exibe o endereço IP público atribuído à instância EC2. Este IP é usado para acessar a instância remotamente via SSH.
        []
    ```hcl
    output "ec2_public_ip" {
      value = aws_instance.debian_ec2.public_ip
    }
    ```
# Principais mudanças

### Separação em módulos:

-   `compute.tf`: Contém recursos relacionados à instância EC2 (chaves SSH, AMI, configuração da instância, user_data).
-   `network.tf`: Define a VPC, sub-rede, Internet Gateway, tabela de rotas e associações.
-   `security.tf`: Configura o Security Group com regras para SSH, HTTP, HTTPS e tráfego de saída.
-   `variables.tf`: Declara variáveis reutilizáveis (projeto, candidato, allowed_ssh_ips, etc.).
-   `outputs.tf`: Expõe a chave privada e o IP público da EC2.
-   `main.tf`: Configuração do backend remoto (S3) e provedor AWS.

## Problemas corrigidos

### Remoção das tags em `aws_route_table_association`:

-   O recurso `aws_route_table_association.main_association` não suporta tags.


### Acentuação no `aws_security_group.description`:

-   Substituída a descrição "trafego de saida" por "trafego de saida" para usar apenas ASCII.

### Removendo a necessidade de interação durante o upgrade:

-   Adicionado `DEBIAN_FRONTEND=noninteractive` e `-y` ao `user_data` para evitar prompts durante atualizações:

    ```bash
    DEBIAN_FRONTEND=noninteractive apt-get -y upgrade -o DPkg::Lock::Timeout=60
    ```
- Adicionado `DPkg::Lock::Timeout=60` nos apt-get para evitar conflitos de lock

### Uso de `vpc_security_group_ids`:

-   Substituído `security_groups = [aws_security_group.main_sg.name]` por `vpc_security_group_ids = [aws_security_group.main_sg.id]` para compatibilidade com VPC. [Terrform docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance#security_groups-1)

### Abertura das portas 80 e 443:

-   Adicionadas regras de entrada para HTTP (porta 80) e HTTPS (porta 443) no Security Group para acesso externo ao NGINX.

## Melhorias implementadas

### Backend remoto (S3):

-   O estado do Terraform é armazenado em um bucket S3 para maior segurança e colaboração.
-   Configuração em `main.tf`:

    ```hcl
    terraform {
      backend "s3" {
        key            = "terraform.tfstate"
        region         = "us-east-1"
        use_lockfile   = true
      }
    }
    ```

### Variáveis para configuração flexível:

-   `allowed_ssh_ips`: Permite definir IPs autorizados via linha de comando:

    ```bash
    terraform apply -var='allowed_ssh_ips=["123.45.67.89/32"]'
    ```

### Lock state:

-   `use_lockfile = true` evita conflitos de estado durante operações simultâneas.

## Pré-requisitos

### Instalar terraform:

-   Siga as instruções oficiais: [Terraform Installation](https://learn.hashicorp.com/tutorials/terraform/install).

### Configurar AWS CLI:

-   Instale a AWS CLI e configure as credenciais:

    ```bash
    aws configure
    ```

### Aceitar termos da AMI Debian 12:

-   Acesse o link e inscreva na imagem no AWS Marketplace: [Debian 12 AMI](https://aws.amazon.com/marketplace/pp/prodview-kujvvq7m246wi).

## Notas de uso

### Para reproduzir a arquitetura:
- Crie um bucket S3 para utilizar o backend remoto
- Clone o repositório
    ```bash
    git clone https://github.com/phaelcampos/desafio-VExpenses.git
    ```
- Inicie o terraform na pasta new_project, e coloque o nome do bucket criado anteriormente
    ````bash
     terraform init -backend-config="bucket={nome_do_bucket}"
     ````
- Crie o plano de execução
    ```bash
    terraform plan -out {nome_do_plano}
  ```
- Execute o plano
    ```bash
      terraform apply {nome_do_plano}
    ```
- Para acessar a aplicação, espere um momento para a instância iniciar e instalar o nginx e acesse o IP retornado no output na porta 80
### Caso precise acessar a chave SSH:

  ```bash
    terraform output -raw private_key > chave_privada.pem
  ```
  ```bash
    chmod 400 chave_privada.pem
  ```
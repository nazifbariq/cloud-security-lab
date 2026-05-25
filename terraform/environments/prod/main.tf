# 1. Provider
provider "aws" {
  region = "ap-southeast-1"
}

# 2. VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "vpc-security-lab" }
}

# 3. Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# 4. Subnet & Routing
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-southeast-1a"
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public_1_assoc" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

# 5. Security Group (FIXED: Added Wazuh Ports)
resource "aws_security_group" "security_lab_sg" {
  name   = "security-lab-sg-v2"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # WAWAUH COMMUNICATION PORTS
  ingress {
    from_port   = 1514
    to_port     = 1515
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
  	create_before_destroy = true
  }
}

# 6. Key Pair
resource "aws_key_pair" "deployer" {
  key_name   = "security-lab-key"
  public_key = file("~/.ssh/security-lab-key.pub")
}

# 7. EC2 Instance
resource "aws_instance" "wazuh_manager" {
  ami                         = "ami-01811d4912b4ccb26"
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.public_1.id
  vpc_security_group_ids      = [aws_security_group.security_lab_sg.id]
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.wazuh_manager_profile.name

  user_data =  <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s2>/dev/tty) 2>&1

              echo "=== 1. Mengonfigurasi SWAP 4GB ==="
              fallocate -l 4G /swapfile
              chmod 600 /swapfile
              mkswap /swapfile
              swapon /swapfile
              echo '/swapfile none swap sw 0 0' >> /etc/fstab

              echo "=== 2. Optimasi Kernel untuk Wazuh Indexer ==="
              echo "vm.max_map_count=262144" >> /etc/sysctl.conf
              sysctl -p

              echo "=== 3. Instalasi Docker & Docker Compose ==="
              apt-get update -y
              apt-get install -y ca-certificates curl gnupg lsb-release git
              mkdir -p /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb-release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
              systemctl enable docker
              systemctl start docker

              echo "=== 4. Clone Repo Wazuh Docker (Single Node v4.7.5) ==="
              git clone https://github.com/wazuh/wazuh-docker.git -b v4.7.5 --single-branch /opt/wazuh-docker
              cd /opt/wazuh-docker

              echo "=== 5. Generate SSL Certificates untuk Cluster ==="
              docker compose -f generate-certs.yml run --rm generator

              echo "=== 6. Menjalankan Wazuh Stack ==="
              # Menggunakan single-node configuration karena resource terbatas
              docker compose -f single-node.yml up -d
              EOF
               
  root_block_device {
    volume_size = 20
  }

  tags = { Name = "Wazuh-Manager" }
}

resource "aws_eip" "wazuh_eip" {
  instance = aws_instance.wazuh_manager.id
  domain   = "vpc"
}

#=========INFRA================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Tambahkan blok ini
  backend "s3" {
    bucket         = "storage-tfstate-najip-cloud-lab" # Samakan dengan nama bucket di Langkah 1
    key            = "prod/wazuh-lab.tfstate"     # Path penyimpanan di dalam S3
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-lab-locks"        # Samakan dengan nama DynamoDB di Langkah 1
    encrypt        = true
  }
}

output "wazuh_manager_static_ip" {
  value = aws_eip.wazuh_eip.public_ip
}

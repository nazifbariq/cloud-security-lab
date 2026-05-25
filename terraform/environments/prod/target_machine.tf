# --- Security Group untuk Target Machine ---
resource "aws_security_group" "target_sg" {
  name        = "target-machine-sg"
  description = "Allow pentesting from Parrot and telemetry to Wazuh"
  vpc_id      = aws_vpc.main.id # Pastikan nama VPC sesuai dengan file main.tf Anda

  # Inbound: SSH dari IP Publik Anda (Parrot OS)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Ganti dengan hasil 'curl ifconfig.me'
  }

  # Inbound: ICMP (Ping) untuk testing koneksi
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/32"]
  }

  # Inbound: Port serangan simulasi (Misal: HTTP/Nginx)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/32"]
  }

  # Outbound: Semua trafik keluar (Ke internet & Wazuh Manager)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "target-sg"
  }
}

# --- Instance EC2: Target Machine ---
resource "aws_instance" "target_node" {
  ami           = "ami-01811d4912b4ccb26" # Ubuntu 22.04 LTS (Region: us-east-1, sesuaikan dengan region Anda)
  instance_type = "t3.micro"              # Masuk dalam Free Tier
  
  subnet_id                   = aws_subnet.public_1.id
  vpc_security_group_ids      = [aws_security_group.target_sg.id]
  key_name                    = "security-lab-key" # Gunakan SSH Key yang sudah ada
  associate_public_ip_address = true

  tags = {
    Name = "ubuntu-target-cloud"
    Role = "Security-Lab-Target"
  }

  # User data untuk otomatisasi instalasi dasar
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y auditd
              systemctl start auditd
              systemctl enable auditd
              EOF
}

# --- Output IP untuk memudahkan akses ---
output "target_public_ip" {
  value = aws_instance.target_node.public_ip
}

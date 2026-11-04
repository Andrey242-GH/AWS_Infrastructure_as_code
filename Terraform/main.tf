terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  subnets = {
    Public_Subnet_1 = {
      cidr_block        = "10.0.1.0/24"
      availability_zone = "us-east-1a"
    }
    Private_Subnet_1 = {
      cidr_block        = "10.0.10.0/24"
      availability_zone = "us-east-1a"
    }
    Public_Subnet_2 = {
      cidr_block        = "10.0.2.0/24"
      availability_zone = "us-east-1b"
    }
  }

  # Only subnets whose name starts with "Public_" get internet access.
  public_subnets = {
    for name, config in local.subnets : name => config
    if strcontains(name, "Public_")
  }
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_subnet" "subnets" {
  for_each = local.subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  # Instances launched into a public subnet automatically receive a public IPv4
  # address. Private subnets do not get this setting — they route outbound
  # traffic through the NAT Gateway instead.
  map_public_ip_on_launch = strcontains(each.key, "Public_")

  tags = {
    Name = each.key
  }
}

# -------------------------
# Internet Gateway
# -------------------------
# Creates the IGW and attaches it to the VPC in a single resource.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "my-codeCreatedIGW"
  }
}

# -------------------------
# Route Table for public subnets
# -------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # The 0.0.0.0/0 route pointing at the IGW is what makes a subnet "public".
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "Public_Route_Table"
  }
}

# Associate every public subnet with the public route table.
# for_each iterates only over local.public_subnets (the filtered map),
# so private subnets are automatically excluded — they stay on the
# VPC's default main route table which has no internet route.
resource "aws_route_table_association" "public" {
  for_each = local.public_subnets

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.public.id
}

# -------------------------
# Elastic IP for NAT Gateway
# -------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "my-codeCreatedNATGW-EIP"
  }
}

# -------------------------
# NAT Gateway (placed in Public_Subnet_1)
# -------------------------
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.subnets["Public_Subnet_1"].id

  tags = {
    Name = "my-codeCreatedNATGW"
  }

  # NAT GW requires the IGW to exist first
  depends_on = [aws_internet_gateway.main]
}

# -------------------------
# Route Table for private subnets
# -------------------------
# Routes outbound traffic from private subnets through the NAT Gateway
# so instances can reach the internet without being directly reachable.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "Private_Route_Table"
  }
}

# Associate every private subnet with the private route table.
locals {
  private_subnets = {
    for name, config in local.subnets : name => config
    if strcontains(name, "Private_")
  }
}

resource "aws_route_table_association" "private" {
  for_each = local.private_subnets

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.private.id
}

# -------------------------
# AMI — latest Amazon Linux 2023 (uses dnf, required by the user-data script)
# -------------------------
# A data source does not create anything; it just looks up an existing value.
# Using a data source here means the AMI ID is always current for the region
# instead of being a hardcoded ID that eventually stops working.
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -------------------------
# User-data script (shared by all three instances)
# -------------------------
locals {
  user_data = <<-EOF
    #!/bin/bash
    set -Eeuo pipefail

    # Save script output so setup problems can be diagnosed after launch.
    exec > >(tee -a /var/log/user-data.log) 2>&1

    APP_DIR="/opt/Heartbeat_Automation"
    SERVICE_USER="heartbeat_User"
    REPO_URL="https://github.com/Andrey242-GH/Heartbeat_Python_Automation.git"
    BRANCH="main"

    echo "Starting EC2 Heartbeat Automation setup..."

    # Install operating-system packages required to download and run the app.
    dnf update -y
    dnf install -y git python3 python3-pip

    # Create the service account if it does not already exist.
    if ! id -u "$SERVICE_USER" >/dev/null 2>&1; then
      useradd \
        --system \
        --home-dir "$APP_DIR" \
        --shell /sbin/nologin \
        "$SERVICE_USER"
    fi

    # Download only the selected branch into the path expected by systemd.
    git clone \
      --single-branch \
      --branch "$BRANCH" \
      "$REPO_URL" \
      "$APP_DIR"

    # Let the service account read the app and manage its virtual environment.
    chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR"
    runuser -u "$SERVICE_USER" -- \
      python3 -m venv "$APP_DIR/.venv"

    # Install the Python packages used by the dashboard and heartbeat job.
    runuser -u "$SERVICE_USER" -- \
      "$APP_DIR/.venv/bin/python" -m pip install --upgrade pip
    runuser -u "$SERVICE_USER" -- \
      "$APP_DIR/.venv/bin/python" -m pip install \
      -r "$APP_DIR/requirements.txt"

    # Create storage that the heartbeat account can write to.
    mkdir -p /var/lib/heartbeat
    chown "$SERVICE_USER:$SERVICE_USER" /var/lib/heartbeat
    chmod 750 /var/lib/heartbeat

    # Run the tests before installing and starting the services (Optional).
    cd "$APP_DIR"
    runuser -u "$SERVICE_USER" -- \
      "$APP_DIR/.venv/bin/python" -m pytest -v

    # Install the systemd unit files provided by the repository.
    cp "$APP_DIR/systemd/heartbeat.service" \
      /etc/systemd/system/heartbeat.service
    cp "$APP_DIR/systemd/heartbeat.timer" \
      /etc/systemd/system/heartbeat.timer
    cp "$APP_DIR/systemd/heartbeat-web.service" \
      /etc/systemd/system/heartbeat-web.service

    # Make systemd read the new units, run one heartbeat, and start the services.
    systemctl daemon-reload
    systemctl start heartbeat.service
    systemctl enable --now heartbeat.timer
    systemctl enable --now heartbeat-web.service

    echo "Heartbeat automation deployment completed."
  EOF
}

# -------------------------
# Security Group — ec2_HeartBeat
# -------------------------
resource "aws_security_group" "ec2_heartbeat" {
  name        = "ec2_HeartBeat"
  description = "Allow SSH and HTTP inbound traffic for HeartBeat instances"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic so instances can reach the internet
  # (required for dnf updates and git clone in user-data).
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2_HeartBeat"
  }
}

# -------------------------
# Bastion host — Public_Subnet_1
# -------------------------
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.subnets["Public_Subnet_1"].id
  vpc_security_group_ids      = [aws_security_group.ec2_heartbeat.id]
  # Public subnet has map_public_ip_on_launch = true so a public IP is
  # assigned automatically; no override needed here.
  instance_initiated_shutdown_behavior = "terminate"
  user_data                   = local.user_data
  user_data_replace_on_change = true

  # Only attach a key pair when one was provided
  key_name = var.key_name != "" ? var.key_name : null

  tags = {
    Name = "Bastion_Host"
  }
}

# -------------------------
# Private instances — Private_Subnet_1 (x2)
# -------------------------
resource "aws_instance" "private" {
  count                       = 2
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.subnets["Private_Subnet_1"].id
  vpc_security_group_ids      = [aws_security_group.ec2_heartbeat.id]
  # Private subnet does NOT have auto-assign enabled, so we explicitly
  # request a public IP on these instances.
  associate_public_ip_address = true
  instance_initiated_shutdown_behavior = "terminate"
  user_data                   = local.user_data
  user_data_replace_on_change = true

  key_name = var.key_name != "" ? var.key_name : null

  tags = {
    Name = "Private_HeartBeat_${count.index + 1}"
  }
}

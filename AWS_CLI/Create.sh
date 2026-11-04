#!/usr/bin/env bash
set -euo pipefail

REGION="us-east-1"
VPC_CIDR="10.0.0.0/16"
VPC_NAME="my-codeCreatedVPC"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ $# -gt 1 ]]; then
  printf 'Usage: %s [resource-id-file]\n' "$0" >&2
  exit 2
fi

if [[ $# -eq 1 ]]; then
  ID_FILE=$1
  [[ "$ID_FILE" = /* ]] || ID_FILE="$PWD/$ID_FILE"
else
  ID_FILE="$SCRIPT_DIR/Resources.env"
fi

Subnet_Array=(
  '{"SubnetName": "Public_Subnet_1","AvailabilityZone": "us-east-1a", "SubnetCIDR": "10.0.1.0/24"}'
  '{"SubnetName": "Private_Subnet_1", "AvailabilityZone": "us-east-1a", "SubnetCIDR": "10.0.10.0/24"}'
  '{"SubnetName": "Public_Subnet_2", "AvailabilityZone": "us-east-1b", "SubnetCIDR": "10.0.2.0/24"}'
)

if [[ -s "$ID_FILE" ]]; then
  printf 'Existing resource IDs found in %s.\n' "$ID_FILE"
  bash "$SCRIPT_DIR/Delete.sh" "$ID_FILE"
fi

: > "$ID_FILE"
printf 'REGION=%s\n' "$REGION" > "$ID_FILE"

# -------------------------
# Create VPC and capture ID
# -------------------------
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block "$VPC_CIDR" \
  --region "$REGION" \
  --query 'Vpc.VpcId' \
  --output text)

if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
  printf 'Could not capture the created VPC ID.\n' >&2
  exit 1
fi

printf 'VPC_ID=%s\n' "$VPC_ID" >> "$ID_FILE"
echo "Created VPC with ID: $VPC_ID"

# Name the VPC
aws ec2 create-tags \
  --resources "$VPC_ID" \
  --tags Key=Name,Value="$VPC_NAME" \
  --region "$REGION"

# -------------------------
# Create subnets
# -------------------------

for subnet in "${Subnet_Array[@]}"; do
  SUBNET_NAME=$(echo "$subnet" | jq -r '.SubnetName')
  SUBNET_CIDR=$(echo "$subnet" | jq -r '.SubnetCIDR')
  AVAILABILITY_ZONE=$(echo "$subnet" | jq -r '.AvailabilityZone')

  SUBNET_ID=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block "$SUBNET_CIDR" \
    --availability-zone "$AVAILABILITY_ZONE" \
    --region "$REGION" \
    --query 'Subnet.SubnetId' \
    --output text)

  if [[ -z "$SUBNET_ID" || "$SUBNET_ID" == "None" ]]; then
    printf 'Could not capture the ID for subnet %s.\n' "$SUBNET_NAME" >&2
    exit 1
  fi

  printf 'SUBNET_%s_ID=%s\n' "$SUBNET_NAME" "$SUBNET_ID" >> "$ID_FILE"
  echo "Created Subnet: $SUBNET_NAME with ID: $SUBNET_ID"

  # Name the subnet
  aws ec2 create-tags \
    --resources "$SUBNET_ID" \
    --tags Key=Name,Value="$SUBNET_NAME" \
    --region "$REGION"

  # Enable auto-assign public IPv4 for public subnets so instances launched
  # there receive a public IP address without needing to request one explicitly.
  if [[ "$SUBNET_NAME" == Public_* ]]; then
    aws ec2 modify-subnet-attribute \
      --subnet-id "$SUBNET_ID" \
      --map-public-ip-on-launch \
      --region "$REGION"
    echo "Enabled auto-assign public IPv4 for $SUBNET_NAME"
  fi
done

# -------------------------
# Create Internet Gateway and attach to VPC
# -------------------------
IGW_ID=$(aws ec2 create-internet-gateway \
  --region "$REGION" \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

if [[ -z "$IGW_ID" || "$IGW_ID" == "None" ]]; then
  printf 'Could not capture the created Internet Gateway ID.\n' >&2
  exit 1
fi

printf 'IGW_ID=%s\n' "$IGW_ID" >> "$ID_FILE"
echo "Created Internet Gateway with ID: $IGW_ID"

# Name the Internet Gateway
aws ec2 create-tags \
  --resources "$IGW_ID" \
  --tags Key=Name,Value="my-codeCreatedIGW" \
  --region "$REGION"

# Attach the Internet Gateway to the VPC
aws ec2 attach-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id "$VPC_ID" \
  --region "$REGION"

echo "Attached Internet Gateway $IGW_ID to VPC $VPC_ID"

# -------------------------
# Create Route Table for public subnets
# -------------------------
RTB_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --region "$REGION" \
  --query 'RouteTable.RouteTableId' \
  --output text)

if [[ -z "$RTB_ID" || "$RTB_ID" == "None" ]]; then
  printf 'Could not capture the created Route Table ID.\n' >&2
  exit 1
fi

printf 'RTB_ID=%s\n' "$RTB_ID" >> "$ID_FILE"
echo "Created Route Table with ID: $RTB_ID"

# Name the Route Table
aws ec2 create-tags \
  --resources "$RTB_ID" \
  --tags Key=Name,Value="Public_Route_Table" \
  --region "$REGION"

# Add a route: 0.0.0.0/0 -> Internet Gateway (this is what makes subnets "public")
aws ec2 create-route \
  --route-table-id "$RTB_ID" \
  --destination-cidr-block "0.0.0.0/0" \
  --gateway-id "$IGW_ID" \
  --region "$REGION"

echo "Added route 0.0.0.0/0 -> IGW $IGW_ID to Route Table $RTB_ID"

# -------------------------
# Associate only the public subnets with the route table
# -------------------------
ASSOC_INDEX=0
for subnet in "${Subnet_Array[@]}"; do
  SUBNET_NAME=$(echo "$subnet" | jq -r '.SubnetName')

  # Skip private subnets — only public subnets get the internet route
  if [[ "$SUBNET_NAME" != Public_* ]]; then
    continue
  fi

  SUBNET_ID=$(grep "^SUBNET_${SUBNET_NAME}_ID=" "$ID_FILE" | cut -d= -f2)

  ASSOC_ID=$(aws ec2 associate-route-table \
    --route-table-id "$RTB_ID" \
    --subnet-id "$SUBNET_ID" \
    --region "$REGION" \
    --query 'AssociationId' \
    --output text)

  if [[ -z "$ASSOC_ID" || "$ASSOC_ID" == "None" ]]; then
    printf 'Could not associate subnet %s with route table.\n' "$SUBNET_NAME" >&2
    exit 1
  fi

  printf 'RTB_ASSOC_%s_ID=%s\n' "$SUBNET_NAME" "$ASSOC_ID" >> "$ID_FILE"
  echo "Associated $SUBNET_NAME ($SUBNET_ID) with Route Table $RTB_ID"
  ASSOC_INDEX=$((ASSOC_INDEX + 1))
done

# -------------------------
# Allocate Elastic IP for NAT Gateway
# -------------------------
EIP_ALLOC_ID=$(aws ec2 allocate-address \
  --domain vpc \
  --region "$REGION" \
  --query 'AllocationId' \
  --output text)

if [[ -z "$EIP_ALLOC_ID" || "$EIP_ALLOC_ID" == "None" ]]; then
  printf 'Could not allocate Elastic IP.\n' >&2
  exit 1
fi

printf 'EIP_ALLOC_ID=%s\n' "$EIP_ALLOC_ID" >> "$ID_FILE"
echo "Allocated Elastic IP with Allocation ID: $EIP_ALLOC_ID"

# Name the EIP
aws ec2 create-tags \
  --resources "$EIP_ALLOC_ID" \
  --tags Key=Name,Value="my-codeCreatedNATGW-EIP" \
  --region "$REGION"

# -------------------------
# Create NAT Gateway in Public_Subnet_1
# -------------------------
PUBLIC_SUBNET_1_ID=$(grep "^SUBNET_Public_Subnet_1_ID=" "$ID_FILE" | cut -d= -f2)

NATGW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id "$PUBLIC_SUBNET_1_ID" \
  --allocation-id "$EIP_ALLOC_ID" \
  --region "$REGION" \
  --query 'NatGateway.NatGatewayId' \
  --output text)

if [[ -z "$NATGW_ID" || "$NATGW_ID" == "None" ]]; then
  printf 'Could not create NAT Gateway.\n' >&2
  exit 1
fi

printf 'NATGW_ID=%s\n' "$NATGW_ID" >> "$ID_FILE"
echo "Created NAT Gateway with ID: $NATGW_ID"

# Name the NAT Gateway
aws ec2 create-tags \
  --resources "$NATGW_ID" \
  --tags Key=Name,Value="my-codeCreatedNATGW" \
  --region "$REGION"

# Wait for the NAT Gateway to become available before creating routes
echo "Waiting for NAT Gateway $NATGW_ID to become available..."
aws ec2 wait nat-gateway-available \
  --nat-gateway-ids "$NATGW_ID" \
  --region "$REGION"
echo "NAT Gateway $NATGW_ID is available."

# -------------------------
# Create Route Table for private subnets
# -------------------------
PRIVATE_RTB_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --region "$REGION" \
  --query 'RouteTable.RouteTableId' \
  --output text)

if [[ -z "$PRIVATE_RTB_ID" || "$PRIVATE_RTB_ID" == "None" ]]; then
  printf 'Could not create private Route Table.\n' >&2
  exit 1
fi

printf 'PRIVATE_RTB_ID=%s\n' "$PRIVATE_RTB_ID" >> "$ID_FILE"
echo "Created Private Route Table with ID: $PRIVATE_RTB_ID"

# Name the private route table
aws ec2 create-tags \
  --resources "$PRIVATE_RTB_ID" \
  --tags Key=Name,Value="Private_Route_Table" \
  --region "$REGION"

# Add route: 0.0.0.0/0 -> NAT Gateway
aws ec2 create-route \
  --route-table-id "$PRIVATE_RTB_ID" \
  --destination-cidr-block "0.0.0.0/0" \
  --nat-gateway-id "$NATGW_ID" \
  --region "$REGION"

echo "Added route 0.0.0.0/0 -> NAT GW $NATGW_ID to Private Route Table $PRIVATE_RTB_ID"

# -------------------------
# Associate private subnets with the private route table
# -------------------------
for subnet in "${Subnet_Array[@]}"; do
  SUBNET_NAME=$(echo "$subnet" | jq -r '.SubnetName')

  # Only private subnets
  if [[ "$SUBNET_NAME" != Private_* ]]; then
    continue
  fi

  SUBNET_ID=$(grep "^SUBNET_${SUBNET_NAME}_ID=" "$ID_FILE" | cut -d= -f2)

  PRIVATE_ASSOC_ID=$(aws ec2 associate-route-table \
    --route-table-id "$PRIVATE_RTB_ID" \
    --subnet-id "$SUBNET_ID" \
    --region "$REGION" \
    --query 'AssociationId' \
    --output text)

  if [[ -z "$PRIVATE_ASSOC_ID" || "$PRIVATE_ASSOC_ID" == "None" ]]; then
    printf 'Could not associate subnet %s with private route table.\n' "$SUBNET_NAME" >&2
    exit 1
  fi

  printf 'PRIVATE_RTB_ASSOC_%s_ID=%s\n' "$SUBNET_NAME" "$PRIVATE_ASSOC_ID" >> "$ID_FILE"
  echo "Associated $SUBNET_NAME ($SUBNET_ID) with Private Route Table $PRIVATE_RTB_ID"
done

# -------------------------
# Resolve the latest Amazon Linux 2023 AMI for the region
# (uses dnf, which matches the user-data script)
# -------------------------
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters \
    "Name=name,Values=al2023-ami-*-x86_64" \
    "Name=virtualization-type,Values=hvm" \
    "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --region "$REGION" \
  --output text)

if [[ -z "$AMI_ID" || "$AMI_ID" == "None" ]]; then
  printf 'Could not resolve Amazon Linux 2023 AMI.\n' >&2
  exit 1
fi

printf 'AMI_ID=%s\n' "$AMI_ID" >> "$ID_FILE"
echo "Resolved AMI: $AMI_ID"

# -------------------------
# User-data script (shared by all three instances)
# -------------------------
USER_DATA=$(cat <<'USERDATA'
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
USERDATA
)

# -------------------------
# Security Group — ec2_HeartBeat
# -------------------------
SG_ID=$(aws ec2 create-security-group \
  --group-name "ec2_HeartBeat" \
  --description "Allow SSH and HTTP inbound traffic for HeartBeat instances" \
  --vpc-id "$VPC_ID" \
  --region "$REGION" \
  --query 'GroupId' \
  --output text)

if [[ -z "$SG_ID" || "$SG_ID" == "None" ]]; then
  printf 'Could not create security group.\n' >&2
  exit 1
fi

printf 'SG_ID=%s\n' "$SG_ID" >> "$ID_FILE"
echo "Created Security Group ec2_HeartBeat with ID: $SG_ID"

aws ec2 create-tags \
  --resources "$SG_ID" \
  --tags Key=Name,Value="ec2_HeartBeat" \
  --region "$REGION"

# SSH inbound — port 22
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0 \
  --region "$REGION"
echo "Added SSH (port 22) inbound rule to $SG_ID"

# HTTP inbound — port 80
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --region "$REGION"
echo "Added HTTP (port 80) inbound rule to $SG_ID"

# -------------------------
# Bastion host — Public_Subnet_1
# -------------------------
PUBLIC_SUBNET_1_ID=$(grep "^SUBNET_Public_Subnet_1_ID=" "$ID_FILE" | cut -d= -f2)

BASTION_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "t2.micro" \
  --subnet-id "$PUBLIC_SUBNET_1_ID" \
  --security-group-ids "$SG_ID" \
  --instance-initiated-shutdown-behavior terminate \
  --user-data "$USER_DATA" \
  --region "$REGION" \
  --query 'Instances[0].InstanceId' \
  --output text)

if [[ -z "$BASTION_ID" || "$BASTION_ID" == "None" ]]; then
  printf 'Could not launch bastion instance.\n' >&2
  exit 1
fi

printf 'BASTION_ID=%s\n' "$BASTION_ID" >> "$ID_FILE"
echo "Launched Bastion_Host with ID: $BASTION_ID"

aws ec2 create-tags \
  --resources "$BASTION_ID" \
  --tags Key=Name,Value="Bastion_Host" \
  --region "$REGION"

# -------------------------
# Private instances — Private_Subnet_1 (x2)
# Auto-assign public IP is enabled per-instance because the subnet itself
# does not have map_public_ip_on_launch set.
# -------------------------
PRIVATE_SUBNET_1_ID=$(grep "^SUBNET_Private_Subnet_1_ID=" "$ID_FILE" | cut -d= -f2)

for i in 1 2; do
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "t2.micro" \
    --subnet-id "$PRIVATE_SUBNET_1_ID" \
    --security-group-ids "$SG_ID" \
    --associate-public-ip-address \
    --instance-initiated-shutdown-behavior terminate \
    --user-data "$USER_DATA" \
    --region "$REGION" \
    --query 'Instances[0].InstanceId' \
    --output text)

  if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "None" ]]; then
    printf 'Could not launch Private_HeartBeat_%s.\n' "$i" >&2
    exit 1
  fi

  printf 'PRIVATE_INSTANCE_%s_ID=%s\n' "$i" "$INSTANCE_ID" >> "$ID_FILE"
  echo "Launched Private_HeartBeat_$i with ID: $INSTANCE_ID"

  aws ec2 create-tags \
    --resources "$INSTANCE_ID" \
    --tags Key=Name,Value="Private_HeartBeat_$i" \
    --region "$REGION"
done

printf '\nCreated resource IDs (also saved to %s):\n' "$ID_FILE"
cat "$ID_FILE"

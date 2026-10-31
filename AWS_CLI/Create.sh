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

printf '\nCreated resource IDs (also saved to %s):\n' "$ID_FILE"
cat "$ID_FILE"

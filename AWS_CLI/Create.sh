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

printf '\nCreated resource IDs (also saved to %s):\n' "$ID_FILE"
cat "$ID_FILE"

# -------------------------
# Configuration
# -------------------------
REGION="us-east-1"
VPC_CIDR="10.0.0.0/16"

# -------------------------
# Create VPC and capture ID
# -------------------------
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block "$VPC_CIDR" \
  --region "$REGION" \
  --query 'Vpc.VpcId' \
  --output text)

echo "VPC_ID=$VPC_ID"

# Name the VPC
aws ec2 create-tags \
  --resources "$VPC_ID" \
  --tags Key=Name,Value=my-vpc \
  --region "$REGION"

# -------------------------
# Create subnets
# -------------------------
SUBNET_1_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block "10.0.1.0/24" \
  --availability-zone "${REGION}a" \
  --region "$REGION" \
  --query 'Subnet.SubnetId' \
  --output text)

SUBNET_2_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block "10.0.2.0/24" \
  --availability-zone "${REGION}b" \
  --region "$REGION" \
  --query 'Subnet.SubnetId' \
  --output text)

echo "VPC:      $VPC_ID"
echo "Subnet 1: $SUBNET_1_ID"
echo "Subnet 2: $SUBNET_2_ID"
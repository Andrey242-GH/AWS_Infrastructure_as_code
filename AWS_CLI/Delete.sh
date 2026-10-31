#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 ]]; then
  printf 'Usage: %s [resource-id-file]\n' "$0" >&2
  exit 2
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ID_FILE=${1:-"$SCRIPT_DIR/Resources.env"}
if [[ ! -f "$ID_FILE" ]]; then
  printf 'Resource ID file not found: %s\n' "$ID_FILE" >&2
  exit 1
fi

REGION=''
VPC_ID=''
IGW_ID=''
RTB_ID=''
declare -a SUBNET_IDS=()
declare -a RTB_ASSOC_IDS=()
declare -a SEEN_KEYS=()

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" ]] && continue
  if [[ "$line" != *=* ]]; then
    printf 'Invalid line in resource ID file.\n' >&2
    exit 1
  fi

  key=${line%%=*}
  value=${line#*=}
  if [[ -z "$value" ]]; then
    printf 'Missing value for %s in resource ID file.\n' "$key" >&2
    exit 1
  fi

  case "$key" in
    REGION)
      if [[ " ${SEEN_KEYS[*]} " == *" REGION "* ]]; then
        printf 'Duplicate value for REGION in resource ID file.\n' >&2
        exit 1
      fi
      REGION=$value
      ;;
    VPC_ID)
      if [[ " ${SEEN_KEYS[*]} " == *" VPC_ID "* ]]; then
        printf 'Duplicate value for VPC_ID in resource ID file.\n' >&2
        exit 1
      fi
      VPC_ID=$value
      ;;
    IGW_ID)
      if [[ " ${SEEN_KEYS[*]} " == *" IGW_ID "* ]]; then
        printf 'Duplicate value for IGW_ID in resource ID file.\n' >&2
        exit 1
      fi
      IGW_ID=$value
      ;;
    RTB_ID)
      if [[ " ${SEEN_KEYS[*]} " == *" RTB_ID "* ]]; then
        printf 'Duplicate value for RTB_ID in resource ID file.\n' >&2
        exit 1
      fi
      RTB_ID=$value
      ;;
    RTB_ASSOC_*)
      if [[ " ${SEEN_KEYS[*]} " == *" $key "* ]]; then
        printf 'Duplicate value for %s in resource ID file.\n' "$key" >&2
        exit 1
      fi
      RTB_ASSOC_IDS+=("$value")
      ;;
    SUBNET_Public_Subnet_1_ID|SUBNET_Private_Subnet_1_ID|SUBNET_Public_Subnet_2_ID)
      if [[ " ${SEEN_KEYS[*]} " == *" $key "* ]]; then
        printf 'Duplicate value for %s in resource ID file.\n' "$key" >&2
        exit 1
      fi
      SUBNET_IDS+=("$value")
      ;;
    *)
      printf 'Unexpected key in resource ID file: %s\n' "$key" >&2
      exit 1
      ;;
  esac
  SEEN_KEYS+=("$key")
done < "$ID_FILE"

if [[ ! "$REGION" =~ ^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$ ]]; then
  printf 'Missing or invalid AWS region in resource ID file.\n' >&2
  exit 1
fi
if [[ ! "$VPC_ID" =~ ^vpc-[[:xdigit:]]{8,17}$ ]]; then
  printf 'Missing or invalid VPC ID in resource ID file.\n' >&2
  exit 1
fi
# IGW and Route Table are optional (older resource files may not have them)
if [[ -n "$IGW_ID" && ! "$IGW_ID" =~ ^igw-[[:xdigit:]]{8,17}$ ]]; then
  printf 'Invalid Internet Gateway ID in resource ID file.\n' >&2
  exit 1
fi
if [[ -n "$RTB_ID" && ! "$RTB_ID" =~ ^rtb-[[:xdigit:]]{8,17}$ ]]; then
  printf 'Invalid Route Table ID in resource ID file.\n' >&2
  exit 1
fi
if [[ ${#SUBNET_IDS[@]} -eq 0 ]]; then
  printf 'No subnet IDs found in resource ID file.\n' >&2
  exit 1
fi
for subnet_id in "${SUBNET_IDS[@]}"; do
  if [[ ! "$subnet_id" =~ ^subnet-[[:xdigit:]]{8,17}$ ]]; then
    printf 'Invalid subnet ID in resource ID file.\n' >&2
    exit 1
  fi
done

ID_FILE=$(realpath -- "$ID_FILE")
ACCOUNT_ID=$(aws sts get-caller-identity \
  --region "$REGION" \
  --query 'Account' \
  --output text)

printf 'AWS account: %s\nRegion: %s\nVPC: %s\n' "$ACCOUNT_ID" "$REGION" "$VPC_ID"
[[ -n "$IGW_ID" ]] && printf 'Internet Gateway: %s\n' "$IGW_ID"
[[ -n "$RTB_ID" ]] && printf 'Route Table: %s\n' "$RTB_ID"
printf 'Subnets:\n'
printf '  %s\n' "${SUBNET_IDS[@]}"
printf '\nThis will permanently delete the route table associations, route table, internet gateway, subnets, and the VPC.\n'
read -r -p "Type DELETE to continue: " confirmation
if [[ "$confirmation" != "DELETE" ]]; then
  printf 'Deletion cancelled.\n'
  exit 1
fi

# 1. Disassociate route table from subnets (only if associations exist)
for assoc_id in "${RTB_ASSOC_IDS[@]}"; do
  aws ec2 disassociate-route-table \
    --association-id "$assoc_id" \
    --region "$REGION"
  printf 'Disassociated route table association: %s\n' "$assoc_id"
done

# 2. Delete the route table (only if it exists)
if [[ -n "$RTB_ID" ]]; then
  aws ec2 delete-route-table \
    --route-table-id "$RTB_ID" \
    --region "$REGION"
  printf 'Deleted Route Table: %s\n' "$RTB_ID"
fi

# 3. Detach the internet gateway from the VPC, then delete it (only if it exists)
if [[ -n "$IGW_ID" ]]; then
  aws ec2 detach-internet-gateway \
    --internet-gateway-id "$IGW_ID" \
    --vpc-id "$VPC_ID" \
    --region "$REGION"
  printf 'Detached Internet Gateway: %s\n' "$IGW_ID"

  aws ec2 delete-internet-gateway \
    --internet-gateway-id "$IGW_ID" \
    --region "$REGION"
  printf 'Deleted Internet Gateway: %s\n' "$IGW_ID"
fi

# 4. Delete subnets
for subnet_id in "${SUBNET_IDS[@]}"; do
  aws ec2 delete-subnet \
    --subnet-id "$subnet_id" \
    --region "$REGION"
  printf 'Deleted subnet: %s\n' "$subnet_id"
done

# 5. Delete the VPC
aws ec2 delete-vpc \
  --vpc-id "$VPC_ID" \
  --region "$REGION"
printf 'Deleted VPC: %s\n' "$VPC_ID"

: > "$ID_FILE"
printf 'Resource ID file cleared: %s\n' "$ID_FILE"

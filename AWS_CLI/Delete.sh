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
declare -a SUBNET_IDS=()
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

printf 'AWS account: %s\nRegion: %s\nVPC: %s\nSubnets:\n' "$ACCOUNT_ID" "$REGION" "$VPC_ID"
printf '  %s\n' "${SUBNET_IDS[@]}"
printf '\nThis will permanently delete these subnets and the VPC.\n'
read -r -p "Type DELETE to continue: " confirmation
if [[ "$confirmation" != "DELETE" ]]; then
  printf 'Deletion cancelled.\n'
  exit 1
fi

for subnet_id in "${SUBNET_IDS[@]}"; do
  aws ec2 delete-subnet \
    --subnet-id "$subnet_id" \
    --region "$REGION"
  printf 'Deleted subnet: %s\n' "$subnet_id"
done

aws ec2 delete-vpc \
  --vpc-id "$VPC_ID" \
  --region "$REGION"
printf 'Deleted VPC: %s\n' "$VPC_ID"

: > "$ID_FILE"
printf 'Resource ID file cleared: %s\n' "$ID_FILE"

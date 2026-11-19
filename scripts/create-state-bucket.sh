#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: AWS_PROFILE=aem-lab $0 <globally-unique-bucket-name> <aws-region>" >&2
  exit 2
fi
bucket="$1"
region="$2"
if ! [[ "$bucket" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]]; then
  echo "Invalid S3 bucket name. Use 3–63 lowercase letters/digits/dots/hyphens." >&2
  exit 2
fi
command -v aws >/dev/null || { echo 'AWS CLI required' >&2; exit 2; }
identity="$(aws sts get-caller-identity --query '[Account,Arn]' --output text)"
echo "AWS identity: $identity"
printf 'Create bucket %s in %s? Type CREATE: ' "$bucket" "$region"
read -r reply
[[ "$reply" == CREATE ]] || { echo 'Cancelled'; exit 1; }

if [[ "$region" == 'us-east-1' ]]; then
  aws s3api create-bucket --bucket "$bucket" --region "$region"
else
  aws s3api create-bucket --bucket "$bucket" --region "$region" \
    --create-bucket-configuration "LocationConstraint=$region"
fi

# Security operations are deliberately explicit and idempotent.
aws s3api put-public-access-block --bucket "$bucket" \
  --public-access-block-configuration 'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
aws s3api put-bucket-ownership-controls --bucket "$bucket" \
  --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerEnforced}]'
aws s3api put-bucket-encryption --bucket "$bucket" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-bucket-versioning --bucket "$bucket" \
  --versioning-configuration 'Status=Enabled'

policy_file="$(mktemp)"
trap 'rm -f "$policy_file"' EXIT
cat > "$policy_file" <<EOF
{"Version":"2012-10-17","Statement":[{"Sid":"DenyInsecureTransport","Effect":"Deny","Principal":"*","Action":"s3:*","Resource":["arn:aws:s3:::$bucket","arn:aws:s3:::$bucket/*"],"Condition":{"Bool":{"aws:SecureTransport":"false"}}}]}
EOF
aws s3api put-bucket-policy --bucket "$bucket" --policy "file://$policy_file"
aws s3api get-bucket-versioning --bucket "$bucket"
aws s3api get-bucket-encryption --bucket "$bucket"
aws s3api get-public-access-block --bucket "$bucket"
echo "State bucket created. Configure least-privilege IAM permissions before team/CI access."

#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <globally-unique-bucket-name> <aws-region>" >&2
  exit 1
fi
bucket="$1"
region="$2"
aws sts get-caller-identity --query '{Account:Account,Arn:Arn}' --output json
read -r -p "Create state bucket $bucket in $region in the currently selected AWS account? Type CREATE: " reply
[[ "$reply" == CREATE ]] || { echo "Cancelled"; exit 1; }
if [[ "$region" == "us-east-1" ]]; then
  aws s3api create-bucket --bucket "$bucket" --region "$region"
else
  aws s3api create-bucket --bucket "$bucket" --region "$region" --create-bucket-configuration "LocationConstraint=$region"
fi
aws s3api put-public-access-block --bucket "$bucket" --public-access-block-configuration 'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
aws s3api put-bucket-versioning --bucket "$bucket" --versioning-configuration 'Status=Enabled'
aws s3api put-bucket-encryption --bucket "$bucket" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
cat > /tmp/aem-state-policy-$$.json <<EOF
{"Version":"2012-10-17","Statement":[{"Sid":"DenyInsecureTransport","Effect":"Deny","Principal":"*","Action":"s3:*","Resource":["arn:aws:s3:::$bucket","arn:aws:s3:::$bucket/*"],"Condition":{"Bool":{"aws:SecureTransport":"false"}}}]}
EOF
aws s3api put-bucket-policy --bucket "$bucket" --policy "file:///tmp/aem-state-policy-$$.json"
rm -f "/tmp/aem-state-policy-$$.json"
echo "Created encrypted, versioned bucket $bucket. Configure backend access policies separately."

#!/usr/bin/env bash
# Confirm encryption + audit settings via the AWS CLI (requires configured creds).
#
# Usage: AWS_REGION=ap-southeast-1 ./verify-encryption.sh [name-prefix]
set -uo pipefail

REGION="${AWS_REGION:-ap-southeast-1}"
PREFIX="${1:-mmu-sis-prod}"

echo "================ RDS storage encryption ================"
aws rds describe-db-instances --region "$REGION" \
  --query "DBInstances[?contains(DBInstanceIdentifier, '${PREFIX}')].{ID:DBInstanceIdentifier,Encrypted:StorageEncrypted,KMS:KmsKeyId}" \
  --output table

echo "================ S3 bucket encryption ================"
for b in $(aws s3api list-buckets --query "Buckets[?contains(Name,'${PREFIX}')].Name" --output text); do
  echo "-- $b"
  aws s3api get-bucket-encryption --bucket "$b" \
    --query "ServerSideEncryptionConfiguration.Rules[].ApplyServerSideEncryptionByDefault" \
    --output table 2>/dev/null || echo "   (no SSE config or access denied)"
done

echo "================ Secrets Manager encryption ================"
aws secretsmanager list-secrets --region "$REGION" \
  --query "SecretList[?contains(Name,'${PREFIX}')].{Name:Name,KmsKeyId:KmsKeyId}" \
  --output table

echo "================ CloudTrail status ================"
aws cloudtrail describe-trails --region "$REGION" \
  --query "trailList[?contains(Name,'${PREFIX}')].{Name:Name,KMS:KmsKeyId,MultiRegion:IsMultiRegionTrail,Validation:LogFileValidationEnabled}" \
  --output table

echo
echo "[i] Expected: RDS Encrypted=true; every bucket AES256 or aws:kms; secrets have a KmsKeyId; trail multi-region + validation enabled."

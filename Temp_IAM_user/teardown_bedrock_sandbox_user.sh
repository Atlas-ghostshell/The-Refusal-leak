#!/usr/bin/env bash
# teardown_bedrock_sandbox_user.sh
#
# Deletes everything create_bedrock_sandbox_user.sh made. Run this with
# your normal AWS CLI credentials (same as the creation script), not the
# throwaway ones — the throwaway user doesn't have permission to delete
# itself, on purpose.

set -euo pipefail

IAM_USER_NAME="week6-bedrock-sandbox"

echo "[*] Deleting access keys for $IAM_USER_NAME..."
for KEY_ID in $(aws iam list-access-keys --user-name "$IAM_USER_NAME" --query 'AccessKeyMetadata[].AccessKeyId' --output text); do
  aws iam delete-access-key --user-name "$IAM_USER_NAME" --access-key-id "$KEY_ID"
  echo "    deleted $KEY_ID"
done

echo "[*] Deleting inline policy..."
aws iam delete-user-policy --user-name "$IAM_USER_NAME" --policy-name "Week6BedrockConverseOnly" || true

echo "[*] Deleting user..."
aws iam delete-user --user-name "$IAM_USER_NAME"

echo "[*] Also run this in your current shell to clear the exported credentials from memory:"
echo ""
echo "unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION"
echo ""
echo "Done. $IAM_USER_NAME and everything attached to it no longer exists."

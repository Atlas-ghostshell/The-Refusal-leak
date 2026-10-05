#!/usr/bin/env bash
# create_bedrock_sandbox_user.sh
#
# Creates a throwaway IAM user that can do exactly one thing:
# bedrock:Converse against ONE named model. Nothing else — no
# ListFoundationModels, no other service, no wildcard resource.
#
# Run this with your EXISTING, already-configured AWS CLI credentials
# (whatever profile/admin access you normally use). This script creates
# a NEW, separate, low-privilege user — you are not touching your own
# credentials at any point.
#
# USAGE: edit the three variables below, then run:
#   bash create_bedrock_sandbox_user.sh

set -euo pipefail

# --- EDIT THESE ----------------------------------------------------------
IAM_USER_NAME="week6-bedrock-sandbox"
REGION="us-east-1"
MODEL_ID="anthropic.claude-haiku-4-5-20251001-v1:0"   # foundation-model ID; the Python scripts call the profile below

# Haiku 4.5 is called through its cross-region inference profile in this
# assessment, so the policy needs both resources: the foundation-model ARN
# built from MODEL_ID and the inference-profile ARN built from this ID. The
# modelId passed in the Python scripts must be this same profile ID.
INFERENCE_PROFILE_ID="us.anthropic.claude-haiku-4-5-20251001-v1:0"
# --------------------------------------------------------------------------

echo "[*] Fetching your AWS account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "    Account: $ACCOUNT_ID"

# Resource list starts with the plain foundation-model ARN. Note: this ARN
# has NO account ID segment (::) — foundation models are a shared,
# account-agnostic resource in Bedrock's ARN scheme.
RESOURCES="\"arn:aws:bedrock:${REGION}::foundation-model/${MODEL_ID}\""

if [ -n "$INFERENCE_PROFILE_ID" ]; then
  # Inference profiles DO carry your account ID — different ARN shape
  # entirely from the foundation-model ARN above. Both are needed together
  # when cross-region inference is in play; granting only one is the exact
  # trap that produces a confusing AccessDenied despite "the policy looking
  # right."
  RESOURCES="${RESOURCES}, \"arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:inference-profile/${INFERENCE_PROFILE_ID}\""
fi

POLICY_JSON=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Week6BedrockConverseOnly",
      "Effect": "Allow",
      "Action": "bedrock:Converse",
      "Resource": [${RESOURCES}]
    }
  ]
}
EOF
)

echo "[*] Creating IAM user: $IAM_USER_NAME"
aws iam create-user --user-name "$IAM_USER_NAME" >/dev/null

echo "[*] Attaching inline policy scoped to bedrock:Converse on:"
echo "    - foundation-model/${MODEL_ID}"
if [ -n "$INFERENCE_PROFILE_ID" ]; then
  echo "    - inference-profile/${INFERENCE_PROFILE_ID}"
fi
aws iam put-user-policy \
  --user-name "$IAM_USER_NAME" \
  --policy-name "Week6BedrockConverseOnly" \
  --policy-document "$POLICY_JSON"

echo "[*] Creating access key..."
KEY_JSON=$(aws iam create-access-key --user-name "$IAM_USER_NAME")

ACCESS_KEY_ID=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['AccessKey']['AccessKeyId'])" "$KEY_JSON")
SECRET_KEY=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['AccessKey']['SecretAccessKey'])" "$KEY_JSON")

echo ""
echo "=================================================================="
echo "DONE. Paste these into your CURRENT shell session ONLY."
echo "Do not add these to .bashrc, .zshrc, .env, or any file."
echo "=================================================================="
echo ""
echo "export AWS_ACCESS_KEY_ID=\"${ACCESS_KEY_ID}\""
echo "export AWS_SECRET_ACCESS_KEY=\"${SECRET_KEY}\""
echo "export AWS_DEFAULT_REGION=\"${REGION}\""
echo ""
echo "=================================================================="
echo "When you're done for the day, run teardown_bedrock_sandbox_user.sh"
echo "=================================================================="

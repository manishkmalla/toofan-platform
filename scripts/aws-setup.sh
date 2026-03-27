#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  TooFan — AWS Infrastructure Setup Script
#  Run this once to provision AWS resources before first deploy.
#  Prerequisites: AWS CLI configured (aws configure)
# ─────────────────────────────────────────────────────────────

set -e

# ── CONFIG — edit these ────────────────────────────────────────
APP_NAME="toofan"
AWS_PROFILE="aws-manish"
AWS_REGION="us-east-1"
EC2_INSTANCE_TYPE="t3.small"     # 2 vCPU, 2GB RAM — upgrade if needed
EC2_AMI="ami-0c02fb55189d77ca5"  # Amazon Linux 2023 (us-east-1)
KEY_PAIR_NAME="toofan-keypair"
S3_BUCKET="toofan-uploads-041808556268"

echo "==> Creating ECR repositories..."
aws ecr create-repository --repository-name toofan-backend  --region $AWS_REGION --profile $AWS_PROFILE || true
aws ecr create-repository --repository-name toofan-frontend --region $AWS_REGION --profile $AWS_PROFILE || true

echo "==> Creating S3 bucket for uploads..."
# us-east-1 does NOT accept LocationConstraint
aws s3api create-bucket \
  --bucket $S3_BUCKET \
  --region $AWS_REGION \
  --profile $AWS_PROFILE

# Block all public access (files served via signed URLs or backend proxy)
aws s3api put-public-access-block \
  --bucket $S3_BUCKET \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
  --profile $AWS_PROFILE

echo "==> Creating EC2 key pair..."
aws ec2 create-key-pair \
  --key-name $KEY_PAIR_NAME \
  --query 'KeyMaterial' \
  --output text \
  --region $AWS_REGION \
  --profile $AWS_PROFILE > ${KEY_PAIR_NAME}.pem
chmod 400 ${KEY_PAIR_NAME}.pem
echo "    Key saved to ${KEY_PAIR_NAME}.pem — keep this safe!"

echo "==> Creating security group..."
SG_ID=$(aws ec2 create-security-group \
  --group-name "${APP_NAME}-sg" \
  --description "TooFan platform security group" \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'GroupId' --output text)

# Allow SSH, HTTP, HTTPS, and backend port
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22   --cidr 0.0.0.0/0 --region $AWS_REGION --profile $AWS_PROFILE
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80   --cidr 0.0.0.0/0 --region $AWS_REGION --profile $AWS_PROFILE
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 443  --cidr 0.0.0.0/0 --region $AWS_REGION --profile $AWS_PROFILE
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 5000 --cidr 0.0.0.0/0 --region $AWS_REGION --profile $AWS_PROFILE

echo "==> Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $EC2_AMI \
  --instance-type $EC2_INSTANCE_TYPE \
  --key-name $KEY_PAIR_NAME \
  --security-group-ids $SG_ID \
  --user-data file://scripts/ec2-userdata.sh \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${APP_NAME}-server}]" \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'Instances[0].InstanceId' --output text)

echo "    Instance ID: $INSTANCE_ID"
echo "    Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $AWS_REGION --profile $AWS_PROFILE

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text --region $AWS_REGION --profile $AWS_PROFILE)

echo ""
echo "✅  AWS setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "EC2 Public IP  : $PUBLIC_IP"
echo "S3 Bucket      : $S3_BUCKET"
echo "Key Pair file  : ${KEY_PAIR_NAME}.pem"
echo ""
echo "Next steps:"
echo "  1. Add GitHub Secrets (see DEPLOY.md)"
echo "  2. SSH in: ssh -i ${KEY_PAIR_NAME}.pem ec2-user@$PUBLIC_IP"
echo "  3. Copy .env: scp -i ${KEY_PAIR_NAME}.pem .env ec2-user@$PUBLIC_IP:~/toofan-platform/"
echo "  4. Push to main branch to trigger deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

#!/usr/bin/env bash
set -euo pipefail
for cmd in aws terraform docker kubectl helm; do
 command -v "$cmd" >/dev/null || { echo "Missing $cmd" >&2; exit 1; }
done
account=$(aws sts get-caller-identity --query Account --output text)
region="${AWS_REGION:-us-east-2}"
bucket="fedorstoiets-neoversity-tfstate-${account}"
aws s3api head-object --bucket "$bucket" --key lesson-5/terraform.tfstate --region "$region" >/dev/null
vpc=$(aws ec2 describe-vpcs --region "$region" --filters Name=tag:Name,Values=lesson-5-vpc --query 'Vpcs[0].VpcId' --output text)
[[ "$vpc" != "None" && -n "$vpc" ]] || { echo 'lesson-5 VPC missing: restore using lesson-5 Terraform first.' >&2;exit 1; }
ng=$(aws ec2 describe-nat-gateways --region "$region" --filter Name=vpc-id,Values="$vpc" Name=state,Values=available --query 'length(NatGateways)' --output text)
[[ "$ng" -gt 0 ]] || { echo 'No NAT gateway in lesson-5 VPC. EKS private nodes may not pull images or register.' >&2;exit 1; }
echo "Prerequisites OK: AWS $account, VPC $vpc, NAT gateways $ng"

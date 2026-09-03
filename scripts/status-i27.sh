#!/usr/bin/env bash

set -u

AWS_PROFILE="${AWS_PROFILE:-i27-devops}"
AWS_REGION="${AWS_REGION:-ap-south-2}"

CLUSTER="i27-helpdesk-dev-eks"
NODEGROUP="i27-helpdesk-dev-eks-nodes"
RDS="i27-helpdesk-dev-mysql"
NAMESPACE="i27-helpdesk-dev"

RUNTIME_DIR="$(cd "$(dirname "$0")/.." && pwd)/runtime"
ENV_FILE="${RUNTIME_DIR}/i27-current.env"

mkdir -p "$RUNTIME_DIR"

export AWS_PROFILE
export AWS_REGION
export AWS_DEFAULT_REGION="$AWS_REGION"

echo "=============================================="
echo " i27 Helpdesk AWS Status"
echo "=============================================="
echo

echo "Checking AWS authentication..."

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "❌ AWS login is not active."
  echo
  echo "Run:"
  echo "  aws login"
  echo
  echo "Then rerun:"
  echo "  ./scripts/status-i27.sh"
  exit 1
fi

echo "AWS authentication ✅"
echo

echo "===== DEVOPS EC2 ====="

aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters \
    "Name=tag:Name,Values=i27-helpdesk-dev-jenkins-controller,i27-helpdesk-dev-jenkins-agent,i27-helpdesk-dev-sonarqube" \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,State:State.Name,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress,InstanceId:InstanceId}' \
  --output table

get_ec2_value() {
  local NAME="$1"
  local FIELD="$2"

  aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters \
      "Name=tag:Name,Values=${NAME}" \
      "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query "Reservations[0].Instances[0].${FIELD}" \
    --output text 2>/dev/null
}

JENKINS_CONTROLLER_PUBLIC_IP="$(get_ec2_value i27-helpdesk-dev-jenkins-controller PublicIpAddress)"
JENKINS_CONTROLLER_PRIVATE_IP="$(get_ec2_value i27-helpdesk-dev-jenkins-controller PrivateIpAddress)"

JENKINS_AGENT_PUBLIC_IP="$(get_ec2_value i27-helpdesk-dev-jenkins-agent PublicIpAddress)"
JENKINS_AGENT_PRIVATE_IP="$(get_ec2_value i27-helpdesk-dev-jenkins-agent PrivateIpAddress)"

SONAR_PUBLIC_IP="$(get_ec2_value i27-helpdesk-dev-sonarqube PublicIpAddress)"
SONAR_PRIVATE_IP="$(get_ec2_value i27-helpdesk-dev-sonarqube PrivateIpAddress)"

# AWS CLI may return "None" while an instance is stopped.
normalize_ip() {
  if [ "$1" = "None" ] || [ "$1" = "null" ]; then
    echo ""
  else
    echo "$1"
  fi
}

JENKINS_CONTROLLER_PUBLIC_IP="$(normalize_ip "$JENKINS_CONTROLLER_PUBLIC_IP")"
JENKINS_AGENT_PUBLIC_IP="$(normalize_ip "$JENKINS_AGENT_PUBLIC_IP")"
SONAR_PUBLIC_IP="$(normalize_ip "$SONAR_PUBLIC_IP")"

echo
echo "===== RDS ====="

RDS_STATUS="$(aws rds describe-db-instances \
  --db-instance-identifier "$RDS" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text 2>/dev/null)"

echo "RDS: $RDS_STATUS"

echo
echo "===== EKS NODEGROUP ====="

aws eks describe-nodegroup \
  --cluster-name "$CLUSTER" \
  --nodegroup-name "$NODEGROUP" \
  --region "$AWS_REGION" \
  --query 'nodegroup.{Status:status,Desired:scalingConfig.desiredSize,Min:scalingConfig.minSize,Max:scalingConfig.maxSize}' \
  --output table

echo
echo "===== CURRENT INGRESSES ====="

kubectl get ingress \
  -n "$NAMESPACE" \
  2>/dev/null || echo "No ingresses currently available."

UI_ALB="$(kubectl get ingress i27-helpdesk-ui \
  -n "$NAMESPACE" \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
  2>/dev/null || true)"

echo
echo "===== DISCOVERED ADDRESSES ====="

echo "Jenkins Controller:"
echo "  Public : ${JENKINS_CONTROLLER_PUBLIC_IP:-not assigned}"
echo "  Private: ${JENKINS_CONTROLLER_PRIVATE_IP:-not assigned}"

echo
echo "Jenkins Agent:"
echo "  Public : ${JENKINS_AGENT_PUBLIC_IP:-not assigned}"
echo "  Private: ${JENKINS_AGENT_PRIVATE_IP:-not assigned}"

echo
echo "SonarQube:"
echo "  Public : ${SONAR_PUBLIC_IP:-not assigned}"
echo "  Private: ${SONAR_PRIVATE_IP:-not assigned}"

echo
echo "Application ALB:"
echo "  DNS: ${UI_ALB:-not created}"

cat > "$ENV_FILE" <<ENVEOF
AWS_PROFILE=${AWS_PROFILE}
AWS_REGION=${AWS_REGION}

JENKINS_CONTROLLER_PUBLIC_IP=${JENKINS_CONTROLLER_PUBLIC_IP}
JENKINS_CONTROLLER_PRIVATE_IP=${JENKINS_CONTROLLER_PRIVATE_IP}

JENKINS_AGENT_PUBLIC_IP=${JENKINS_AGENT_PUBLIC_IP}
JENKINS_AGENT_PRIVATE_IP=${JENKINS_AGENT_PRIVATE_IP}

SONAR_PUBLIC_IP=${SONAR_PUBLIC_IP}
SONAR_PRIVATE_IP=${SONAR_PRIVATE_IP}

UI_ALB=${UI_ALB}
ENVEOF

echo
echo "Runtime information written to:"
echo "  $ENV_FILE"

echo
echo "=============================================="
echo " Status check complete ✅"
echo "=============================================="

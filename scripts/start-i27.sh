#!/usr/bin/env bash

set -uo pipefail

AWS_PROFILE="${AWS_PROFILE:-i27-devops}"
AWS_REGION="${AWS_REGION:-ap-south-2}"

CLUSTER="i27-helpdesk-dev-eks"
NODEGROUP="i27-helpdesk-dev-eks-nodes"
RDS="i27-helpdesk-dev-mysql"
NS="i27-helpdesk-dev"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

export AWS_PROFILE
export AWS_REGION
export AWS_DEFAULT_REGION="$AWS_REGION"

echo "=============================================="
echo " Starting i27 Helpdesk AWS Environment"
echo "=============================================="

echo
echo "===== 1. AWS AUTHENTICATION ====="

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "❌ AWS session expired."
  echo
  echo "Run:"
  echo "  aws login"
  exit 1
fi

echo "AWS authentication ✅"

echo
echo "===== 2. START DEVOPS EC2 ====="

STOPPED_IDS="$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters \
    "Name=tag:Name,Values=i27-helpdesk-dev-jenkins-controller,i27-helpdesk-dev-jenkins-agent,i27-helpdesk-dev-sonarqube" \
    "Name=instance-state-name,Values=stopped" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text)"

if [ -n "$STOPPED_IDS" ] && [ "$STOPPED_IDS" != "None" ]; then
  echo "Starting:"
  echo "$STOPPED_IDS"

  aws ec2 start-instances \
    --region "$AWS_REGION" \
    --instance-ids $STOPPED_IDS \
    --query 'StartingInstances[].{Instance:InstanceId,State:CurrentState.Name}' \
    --output table
else
  echo "DevOps EC2 instances already started or starting."
fi

ALL_EC2_IDS="$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters \
    "Name=tag:Name,Values=i27-helpdesk-dev-jenkins-controller,i27-helpdesk-dev-jenkins-agent,i27-helpdesk-dev-sonarqube" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text)"

echo
echo "Waiting for EC2 instances to reach running state..."

if aws ec2 wait instance-running \
  --region "$AWS_REGION" \
  --instance-ids $ALL_EC2_IDS; then
  echo "EC2 instances running ✅"
else
  echo "⚠️ EC2 running waiter timed out."
fi

echo
echo "Waiting for EC2 status checks..."

if aws ec2 wait instance-status-ok \
  --region "$AWS_REGION" \
  --instance-ids $ALL_EC2_IDS; then
  echo "EC2 status checks passed ✅"
else
  echo "⚠️ EC2 status checks are taking longer than expected."
fi

echo
echo "===== 3. START RDS ====="

RDS_STATUS="$(aws rds describe-db-instances \
  --db-instance-identifier "$RDS" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text)"

echo "Current RDS state: $RDS_STATUS"

case "$RDS_STATUS" in
  stopped)
    echo "Starting RDS..."
    aws rds start-db-instance \
      --db-instance-identifier "$RDS" \
      --region "$AWS_REGION" \
      --query 'DBInstance.DBInstanceStatus' \
      --output text
    ;;

  stopping)
    echo "RDS is still stopping. Waiting..."
    aws rds wait db-instance-stopped \
      --db-instance-identifier "$RDS" \
      --region "$AWS_REGION"

    echo "Starting RDS..."
    aws rds start-db-instance \
      --db-instance-identifier "$RDS" \
      --region "$AWS_REGION" \
      --query 'DBInstance.DBInstanceStatus' \
      --output text
    ;;

  available)
    echo "RDS already available ✅"
    ;;

  starting)
    echo "RDS already starting."
    ;;

  *)
    echo "RDS currently in state: $RDS_STATUS"
    ;;
esac

echo "Waiting for RDS to become available..."

if aws rds wait db-instance-available \
  --db-instance-identifier "$RDS" \
  --region "$AWS_REGION"; then
  echo "RDS available ✅"
else
  echo "⚠️ RDS did not become available within waiter timeout."
fi

echo
echo "===== 4. SCALE EKS WORKERS TO 1 ====="

for i in $(seq 1 30); do
  NG_STATUS="$(aws eks describe-nodegroup \
    --cluster-name "$CLUSTER" \
    --nodegroup-name "$NODEGROUP" \
    --region "$AWS_REGION" \
    --query 'nodegroup.status' \
    --output text)"

  if [ "$NG_STATUS" = "ACTIVE" ]; then
    break
  fi

  echo "Waiting for nodegroup ACTIVE... $i/30"
  sleep 10
done

CURRENT_DESIRED="$(aws eks describe-nodegroup \
  --cluster-name "$CLUSTER" \
  --nodegroup-name "$NODEGROUP" \
  --region "$AWS_REGION" \
  --query 'nodegroup.scalingConfig.desiredSize' \
  --output text)"

if [ "$CURRENT_DESIRED" != "1" ]; then
  echo "Scaling nodegroup from $CURRENT_DESIRED -> 1"

  aws eks update-nodegroup-config \
    --cluster-name "$CLUSTER" \
    --nodegroup-name "$NODEGROUP" \
    --region "$AWS_REGION" \
    --scaling-config minSize=0,maxSize=2,desiredSize=1 \
    --query 'update.id' \
    --output text
else
  echo "Nodegroup desired size already 1."
fi

echo
echo "Waiting for nodegroup update..."

for i in $(seq 1 60); do
  NG_STATUS="$(aws eks describe-nodegroup \
    --cluster-name "$CLUSTER" \
    --nodegroup-name "$NODEGROUP" \
    --region "$AWS_REGION" \
    --query 'nodegroup.status' \
    --output text)"

  DESIRED="$(aws eks describe-nodegroup \
    --cluster-name "$CLUSTER" \
    --nodegroup-name "$NODEGROUP" \
    --region "$AWS_REGION" \
    --query 'nodegroup.scalingConfig.desiredSize' \
    --output text)"

  if [ "$NG_STATUS" = "ACTIVE" ] && [ "$DESIRED" = "1" ]; then
    echo "EKS nodegroup ACTIVE, desired=1 ✅"
    break
  fi

  echo "Nodegroup status=$NG_STATUS desired=$DESIRED ($i/60)"
  sleep 10
done

echo
echo "===== 5. REFRESH KUBECONFIG ====="

aws eks update-kubeconfig \
  --name "$CLUSTER" \
  --region "$AWS_REGION" \
  >/dev/null

echo "kubeconfig refreshed ✅"

echo
echo "===== 6. WAIT FOR EKS NODE ====="

NODE_READY=false

for i in $(seq 1 60); do
  READY_COUNT="$(kubectl get nodes --no-headers 2>/dev/null \
    | awk '$2=="Ready" {count++} END {print count+0}')"

  if [ "$READY_COUNT" -ge 1 ]; then
    NODE_READY=true
    echo "EKS worker node Ready ✅"
    kubectl get nodes -o wide
    break
  fi

  echo "Waiting for worker node... $i/60"
  sleep 10
done

if [ "$NODE_READY" != "true" ]; then
  echo "⚠️ Worker node did not become Ready within 10 minutes."
fi

echo
echo "===== 7. WAIT FOR LOAD BALANCER CONTROLLER ====="

if kubectl wait \
  --for=condition=Available \
  deployment/aws-load-balancer-controller \
  -n kube-system \
  --timeout=300s; then

  echo "AWS Load Balancer Controller ready ✅"
else
  echo "⚠️ Load Balancer Controller not ready yet."
fi

echo
echo "===== 8. WAIT FOR APPLICATION DEPLOYMENTS ====="

if kubectl wait \
  --for=condition=Available \
  deployment \
  --all \
  -n "$NS" \
  --timeout=300s; then

  echo "Application deployments ready ✅"
else
  echo "⚠️ Some application deployments are still starting."
  kubectl get pods -n "$NS"
fi

echo
echo "===== 9. RECREATE PUBLIC INGRESSES ====="

kubectl apply \
  -f "$ROOT_DIR/kubernetes/ingress/alb-ingress-class.yaml"

kubectl apply \
  -f "$ROOT_DIR/kubernetes/ingress/gateway-ingress.yaml"

kubectl apply \
  -f "$ROOT_DIR/kubernetes/ingress/ui-ingress.yaml"

echo
echo "===== 10. WAIT FOR APPLICATION ALB ====="

ALB_DNS=""

for i in $(seq 1 60); do
  ALB_DNS="$(kubectl get ingress i27-helpdesk-ui \
    -n "$NS" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
    2>/dev/null || true)"

  if [ -n "$ALB_DNS" ]; then
    echo "ALB created ✅"
    echo "$ALB_DNS"
    break
  fi

  echo "Waiting for ALB hostname... $i/60"
  sleep 10
done

echo
echo "===== 11. REFRESH CURRENT IP ADDRESSES ====="

"$ROOT_DIR/scripts/status-i27.sh"

if [ -f "$ROOT_DIR/runtime/i27-current.env" ]; then
  # shellcheck disable=SC1091
  source "$ROOT_DIR/runtime/i27-current.env"
fi

echo
echo "=============================================="
echo " Environment Started"
echo "=============================================="

echo
echo "Jenkins:"
if [ -n "${JENKINS_CONTROLLER_PUBLIC_IP:-}" ]; then
  echo "  http://${JENKINS_CONTROLLER_PUBLIC_IP}:8080"
else
  echo "  Public IP not available"
fi

echo
echo "SonarQube:"
if [ -n "${SONAR_PUBLIC_IP:-}" ]; then
  echo "  http://${SONAR_PUBLIC_IP}:9000"
else
  echo "  Public IP not available"
fi

echo
echo "Application:"
if [ -n "${UI_ALB:-}" ]; then
  echo "  http://${UI_ALB}"
else
  echo "  ALB still provisioning"
fi

echo
echo "=============================================="
echo " Startup sequence complete ✅"
echo "=============================================="

#!/usr/bin/env bash

set -u

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
echo " Stopping i27 Helpdesk AWS Environment"
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
echo "===== 2. CAPTURE CURRENT APPLICATION ALB ====="

ALB_DNS="$(kubectl get ingress i27-helpdesk-ui \
  -n "$NS" \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
  2>/dev/null || true)"

if [ -n "$ALB_DNS" ]; then
  echo "Current ALB:"
  echo "  $ALB_DNS"
else
  echo "No application ALB currently recorded."
fi

echo
echo "===== 3. DELETE PUBLIC INGRESSES ====="

kubectl delete ingress \
  i27-helpdesk-gateway \
  i27-helpdesk-ui \
  -n "$NS" \
  --ignore-not-found \
  || echo "⚠️ Ingress deletion command reported an error."

echo
echo "===== 4. WAIT FOR ALB DELETION - MAX 4 MINUTES ====="

if [ -n "$ALB_DNS" ]; then
  ALB_DELETED=false

  for i in $(seq 1 24); do
    FOUND="$(aws elbv2 describe-load-balancers \
      --region "$AWS_REGION" \
      --query "LoadBalancers[?DNSName=='${ALB_DNS}'].DNSName" \
      --output text 2>/dev/null || true)"

    if [ -z "$FOUND" ] || [ "$FOUND" = "None" ]; then
      echo "ALB deleted ✅"
      ALB_DELETED=true
      break
    fi

    echo "Waiting for ALB deletion... $i/24"
    sleep 10
  done

  if [ "$ALB_DELETED" != "true" ]; then
    echo "⚠️ ALB deletion is taking longer than 4 minutes."
    echo "Continuing shutdown anyway."
  fi
else
  echo "No ALB to wait for."
fi

echo
echo "===== 5. SCALE EKS WORKERS TO ZERO ====="

NG_STATUS="$(aws eks describe-nodegroup \
  --cluster-name "$CLUSTER" \
  --nodegroup-name "$NODEGROUP" \
  --region "$AWS_REGION" \
  --query 'nodegroup.status' \
  --output text 2>/dev/null || echo UNKNOWN)"

if [ "$NG_STATUS" != "ACTIVE" ]; then
  echo "Nodegroup currently $NG_STATUS. Waiting briefly for ACTIVE..."

  for i in $(seq 1 30); do
    NG_STATUS="$(aws eks describe-nodegroup \
      --cluster-name "$CLUSTER" \
      --nodegroup-name "$NODEGROUP" \
      --region "$AWS_REGION" \
      --query 'nodegroup.status' \
      --output text 2>/dev/null || echo UNKNOWN)"

    [ "$NG_STATUS" = "ACTIVE" ] && break

    echo "Waiting for nodegroup ACTIVE... $i/30"
    sleep 10
  done
fi

CURRENT_DESIRED="$(aws eks describe-nodegroup \
  --cluster-name "$CLUSTER" \
  --nodegroup-name "$NODEGROUP" \
  --region "$AWS_REGION" \
  --query 'nodegroup.scalingConfig.desiredSize' \
  --output text 2>/dev/null || echo UNKNOWN)"

if [ "$CURRENT_DESIRED" = "0" ]; then
  echo "EKS nodegroup already desired=0 ✅"

elif [ "$NG_STATUS" = "ACTIVE" ]; then
  echo "Scaling EKS nodegroup $CURRENT_DESIRED -> 0"

  aws eks update-nodegroup-config \
    --cluster-name "$CLUSTER" \
    --nodegroup-name "$NODEGROUP" \
    --region "$AWS_REGION" \
    --scaling-config minSize=0,maxSize=2,desiredSize=0 \
    --query 'update.id' \
    --output text \
    || echo "⚠️ Unable to submit EKS scale-down request."

else
  echo "⚠️ Nodegroup is $NG_STATUS; scale-down request not submitted."
fi

echo
echo "Waiting for EKS desired size 0 - MAX 10 MINUTES..."

for i in $(seq 1 60); do
  NG_STATUS="$(aws eks describe-nodegroup \
    --cluster-name "$CLUSTER" \
    --nodegroup-name "$NODEGROUP" \
    --region "$AWS_REGION" \
    --query 'nodegroup.status' \
    --output text 2>/dev/null || echo UNKNOWN)"

  DESIRED="$(aws eks describe-nodegroup \
    --cluster-name "$CLUSTER" \
    --nodegroup-name "$NODEGROUP" \
    --region "$AWS_REGION" \
    --query 'nodegroup.scalingConfig.desiredSize' \
    --output text 2>/dev/null || echo UNKNOWN)"

  if [ "$NG_STATUS" = "ACTIVE" ] && [ "$DESIRED" = "0" ]; then
    echo "EKS nodegroup ACTIVE, desired=0 ✅"
    break
  fi

  echo "Nodegroup status=$NG_STATUS desired=$DESIRED ($i/60)"
  sleep 10
done

echo
echo "===== 6. STOP RDS ====="

RDS_STATUS="$(aws rds describe-db-instances \
  --db-instance-identifier "$RDS" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text 2>/dev/null || echo UNKNOWN)"

echo "Current RDS state: $RDS_STATUS"

case "$RDS_STATUS" in
  available)
    echo "Stopping RDS..."

    aws rds stop-db-instance \
      --db-instance-identifier "$RDS" \
      --region "$AWS_REGION" \
      --query 'DBInstance.DBInstanceStatus' \
      --output text \
      || echo "⚠️ RDS stop request failed."
    ;;

  stopped)
    echo "RDS already stopped ✅"
    ;;

  stopping)
    echo "RDS already stopping."
    ;;

  *)
    echo "⚠️ RDS is currently $RDS_STATUS."
    echo "Continuing with EC2 shutdown."
    ;;
esac

echo
echo "Waiting for RDS stopped - MAX 10 MINUTES..."

for i in $(seq 1 60); do
  RDS_STATUS="$(aws rds describe-db-instances \
    --db-instance-identifier "$RDS" \
    --region "$AWS_REGION" \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo UNKNOWN)"

  if [ "$RDS_STATUS" = "stopped" ]; then
    echo "RDS stopped ✅"
    break
  fi

  echo "RDS status=$RDS_STATUS ($i/60)"
  sleep 10
done

echo
echo "===== 7. STOP JENKINS + SONAR EC2 ====="

EC2_IDS="$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters \
    "Name=tag:Name,Values=i27-helpdesk-dev-jenkins-controller,i27-helpdesk-dev-jenkins-agent,i27-helpdesk-dev-sonarqube" \
    "Name=instance-state-name,Values=running,pending" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text)"

if [ -n "$EC2_IDS" ] && [ "$EC2_IDS" != "None" ]; then
  aws ec2 stop-instances \
    --region "$AWS_REGION" \
    --instance-ids $EC2_IDS \
    --query 'StoppingInstances[].{Instance:InstanceId,State:CurrentState.Name}' \
    --output table \
    || echo "⚠️ EC2 stop request reported an error."
else
  echo "DevOps EC2 instances already stopped."
fi

echo
echo "Waiting for DevOps EC2 instances - MAX 5 MINUTES..."

for i in $(seq 1 60); do
  RUNNING_COUNT="$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters \
      "Name=tag:Name,Values=i27-helpdesk-dev-jenkins-controller,i27-helpdesk-dev-jenkins-agent,i27-helpdesk-dev-sonarqube" \
      "Name=instance-state-name,Values=running,pending,stopping" \
    --query 'length(Reservations[].Instances[])' \
    --output text 2>/dev/null || echo 99)"

  if [ "$RUNNING_COUNT" = "0" ]; then
    echo "DevOps EC2 instances stopped ✅"
    break
  fi

  echo "Instances still transitioning: $RUNNING_COUNT ($i/60)"
  sleep 5
done

echo
echo "===== 8. FINAL STATUS ====="

"$ROOT_DIR/scripts/status-i27.sh" || true

echo
echo "=============================================="
echo " Shutdown sequence complete ✅"
echo "=============================================="
echo
echo "Expected overnight state:"
echo "  Jenkins Controller : stopped"
echo "  Jenkins Agent      : stopped"
echo "  SonarQube          : stopped"
echo "  RDS                : stopped"
echo "  EKS desired nodes  : 0"
echo "  Application ALB    : deleted"
echo
echo "EKS control plane and persistent storage remain."

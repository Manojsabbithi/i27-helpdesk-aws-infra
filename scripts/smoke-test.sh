#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUNTIME_FILE="${PROJECT_ROOT}/runtime/i27-current.env"
NAMESPACE="${NAMESPACE:-i27-helpdesk-dev}"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  echo "✅ PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "❌ FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

check_http() {
  local name="$1"
  local url="$2"
  local expected="${3:-200}"

  local code
  code="$(curl -sS --connect-timeout 10 --max-time 20 -o /dev/null -w "%{http_code}" "${url}" 2>/dev/null || true)"

  if [[ "${code}" == "${expected}" ]]; then
    pass "${name} returned HTTP ${code}"
  else
    fail "${name} expected HTTP ${expected}, received ${code:-no-response}"
  fi
}

echo "========================================="
echo " i27 Helpdesk - AWS Smoke Test"
echo "========================================="
echo

for command in curl kubectl; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: ${command}"
    exit 1
  fi
done

if [[ ! -f "${RUNTIME_FILE}" ]]; then
  echo "ERROR: Runtime file not found:"
  echo "  ${RUNTIME_FILE}"
  echo
  echo "Run ./scripts/start-i27.sh first."
  exit 1
fi

# shellcheck disable=SC1090
source "${RUNTIME_FILE}"

if [[ -z "${UI_ALB:-}" ]]; then
  echo "ERROR: UI_ALB is not defined in ${RUNTIME_FILE}"
  exit 1
fi

BASE_URL="http://${UI_ALB}"

pass "Runtime configuration loaded"
echo "Target: ${BASE_URL}"
echo "Namespace: ${NAMESPACE}"
echo
echo "===== PUBLIC APPLICATION ====="

check_http "UI through ALB" "${BASE_URL}/" 200
check_http "Gateway health" "${BASE_URL}/healthz" 200
check_http "Gateway readiness" "${BASE_URL}/readyz" 200

echo
echo "===== KUBERNETES ====="

if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  pass "Kubernetes API reachable and namespace exists"
else
  fail "Cannot reach Kubernetes namespace ${NAMESPACE}"
fi

if kubectl wait node --all --for=condition=Ready --timeout=30s >/dev/null 2>&1; then
  pass "All EKS worker nodes are Ready"
else
  fail "One or more EKS worker nodes are not Ready"
fi

if kubectl wait deployment --all -n "${NAMESPACE}" --for=condition=Available --timeout=60s >/dev/null 2>&1; then
  pass "All deployments are Available"
else
  fail "One or more deployments are not Available"
fi

UNHEALTHY_PODS="$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | awk '$3 != "Running" && $3 != "Completed" {print}' || true)"

if [[ -z "${UNHEALTHY_PODS}" ]]; then
  pass "All application pods are Running or Completed"
else
  fail "Unhealthy application pods detected"
  echo "${UNHEALTHY_PODS}"
fi

echo
NOT_READY_PODS="$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | awk '$3 == "Running" {split($2,a,"/"); if (a[1] != a[2]) print}' || true)"

if [[ -z "${NOT_READY_PODS}" ]]; then
  pass "All Running pods have all containers Ready"
else
  fail "Running pods with unready containers detected"
  echo "${NOT_READY_PODS}"
fi

echo
echo "========================================="
echo " Smoke Test Summary"
echo "========================================="
echo "Passed: ${PASS_COUNT}"
echo "Failed: ${FAIL_COUNT}"
echo

if (( FAIL_COUNT > 0 )); then
  echo "❌ SMOKE TEST FAILED"
  exit 1
fi

echo "✅ SMOKE TEST PASSED"
exit 0

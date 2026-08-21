#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform/environments/dev"
INVENTORY="${REPO_ROOT}/ansible/inventory/dev.ini"

cd "${TF_DIR}"

JENKINS_CONTROLLER_PUBLIC=$(terraform output -raw jenkins_controller_public_ip)
JENKINS_CONTROLLER_PRIVATE=$(terraform output -raw jenkins_controller_private_ip)

JENKINS_AGENT_PUBLIC=$(terraform output -raw jenkins_agent_public_ip)
JENKINS_AGENT_PRIVATE=$(terraform output -raw jenkins_agent_private_ip)

SONARQUBE_PUBLIC=$(terraform output -raw sonarqube_public_ip)
SONARQUBE_PRIVATE=$(terraform output -raw sonarqube_private_ip)

if [[ -n "${SONARQUBE_PUBLIC}" ]]; then
  SONARQUBE_INVENTORY_LINE="sonarqube ansible_host=${SONARQUBE_PUBLIC} private_ip=${SONARQUBE_PRIVATE}"
else
  SONARQUBE_INVENTORY_LINE=""
fi

cat > "${INVENTORY}" <<EOT
[jenkins_controller]
jenkins-controller ansible_host=${JENKINS_CONTROLLER_PUBLIC} private_ip=${JENKINS_CONTROLLER_PRIVATE}

[jenkins_agent]
jenkins-agent ansible_host=${JENKINS_AGENT_PUBLIC} private_ip=${JENKINS_AGENT_PRIVATE}

[sonarqube_servers]
${SONARQUBE_INVENTORY_LINE}

[devops:children]
jenkins_controller
jenkins_agent
sonarqube_servers

[devops:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/i27-helpdesk-aws
ansible_python_interpreter=/usr/bin/python3
EOT

echo "Generated ${INVENTORY}"
cat "${INVENTORY}"

# i27 Helpdesk AWS DevOps Demo Runbook

This runbook provides a repeatable 5-10 minute demonstration of the AWS DevOps and platform engineering implementation around the existing i27 Helpdesk microservices application.

The focus of the demo is the infrastructure, CI/CD, Kubernetes deployment, security, observability, automation, and operational practices implemented for the portfolio project.

## Before the Demo

1. Authenticate to AWS.
2. Start the lab if it is currently scaled down.
3. Run the status script.
4. Run the automated smoke test.
5. Confirm Jenkins, SonarQube, EKS, RDS, and the application are reachable.

```bash
aws login
./scripts/start-i27.sh
./scripts/status-i27.sh
./scripts/smoke-test.sh
```

Never expose passwords, JWTs, AWS credentials, Secrets Manager values, or other sensitive runtime data during the demo.

## Demo Flow

### 1. Project Introduction - 30 seconds

Explain that this is an independent hands-on AWS DevOps portfolio implementation around an existing microservices application.

Cover the main responsibilities:

- AWS infrastructure provisioning
- server configuration management
- containerization and Kubernetes deployment
- CI/CD automation
- security hardening
- monitoring and audit controls
- cost-aware environment operations

### 2. Architecture - 1 minute

Open:

```text
architecture/aws-architecture.md
```

Walk through the request path:

```text
Browser -> ALB -> UI / API Gateway -> Microservices -> RDS / S3 / SES
```

Mention that backend workloads run on EKS, RDS is private, S3 attachments use IRSA, and the public ALB is managed through Kubernetes ingress.

### 3. Infrastructure as Code - 1 minute

Show the Terraform and Ansible repository structure without changing infrastructure:

```bash
find terraform/modules -maxdepth 2 -type f -name "*.tf" | sort
find ansible/roles -maxdepth 2 -type f | sort
```

Explain that Terraform provisions AWS resources and Ansible configures the Jenkins and SonarQube hosts. Daily startup and shutdown are handled separately by operational scripts.

### 4. Live Kubernetes Environment - 1 minute

```bash
kubectl get nodes
kubectl get pods -n i27-helpdesk-dev
kubectl get deployments -n i27-helpdesk-dev
kubectl get ingress -n i27-helpdesk-dev
```

Point out that the services are containerized, deployed to EKS, and exposed through the shared ALB architecture.

### 5. CI/CD - 1 to 2 minutes

Open one successful Jenkins pipeline and walk through:

```text
Checkout
Build and Test
SonarQube Analysis
Quality Gate
Docker Build
ECR Push
EKS Deployment
Rollout Verification
```

### 6. Security - 1 minute

Explain the controls that were implemented and live-tested:

- JWT authentication at the API Gateway
- ADMIN, AGENT, and USER role authorization
- ticket ownership and agent-assignment authorization
- attachment list, upload, and download authorization
- IRSA instead of embedded AWS access keys
- private S3 attachment storage
- Secrets Manager for database credentials
- sensitive authentication data removed from Gateway logs

### 7. Automated Operational Validation - 30 seconds

Run:

```bash
./scripts/smoke-test.sh
```

A healthy environment should finish with 9 passed checks and zero failures.

### 8. Monitoring, Audit, and Cost Controls - 1 minute

Explain:

- CloudWatch dashboards and alarms
- SNS alarm notifications
- CloudTrail API auditing to S3
- AWS Budgets cost guardrails
- automated start, status, and shutdown workflows
- EKS workers scale to zero and EC2/RDS are stopped when the lab is not needed

### 9. Closing - 30 seconds

Summarize the project as an end-to-end DevOps implementation covering infrastructure as code, configuration management, CI/CD, containers, Kubernetes, AWS managed services, security, observability, auditing, troubleshooting, and cost-aware operations.

## Suggested Closing Statement

> The application itself already existed, and my focus in this project was the DevOps and platform engineering around it. I provisioned the AWS infrastructure with Terraform, automated server configuration with Ansible, built Jenkins CI/CD pipelines with SonarQube quality gates, deployed the services to EKS using images from ECR, integrated RDS, S3 and SES, implemented IAM and IRSA controls, hardened application authorization, added CloudWatch and CloudTrail visibility, and created operational automation for startup, shutdown and smoke testing.

## After the Demo

Scale down the lab when it is no longer required:

```bash
./scripts/stop-i27.sh
```

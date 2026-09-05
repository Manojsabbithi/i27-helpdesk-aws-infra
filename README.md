# i27 Helpdesk - AWS DevOps Portfolio Project

An independent hands-on DevOps and cloud engineering project that implements the AWS infrastructure, CI/CD platform, Kubernetes deployment, security controls, observability, and operational automation for the existing **i27 Helpdesk microservices application**.

This repository focuses on the **DevOps and platform engineering implementation** rather than claiming authorship of the original application.

## Project Scope

The project demonstrates how an existing multi-service application can be taken from source repositories to a working AWS environment using infrastructure as code, configuration management, containerization, Kubernetes, CI/CD, security hardening, monitoring, and cost-aware operational automation.

## Architecture

See the detailed [AWS Architecture](architecture/aws-architecture.md) covering runtime traffic flow, CI/CD, infrastructure provisioning, security, monitoring, and operational controls.

## Goal

Build a production-inspired, portfolio-grade AWS DevOps platform that can:

- provision infrastructure reproducibly with Terraform,
- configure DevOps servers with Ansible,
- build and validate application services through Jenkins,
- store container images in Amazon ECR,
- deploy workloads to Amazon EKS,
- run MySQL on Amazon RDS,
- store attachments securely in Amazon S3,
- expose the application through an Application Load Balancer,
- enforce authentication and authorization controls,
- provide monitoring, alerting, and audit logging,
- and support simple daily start/stop operations to control cloud cost.

## Application Services

- Next.js UI
- Node.js API Gateway
- Spring Boot Auth Service
- Spring Boot Ticket Service
- FastAPI Comment Service
- FastAPI Notification Service
- FastAPI Attachment Service
- MySQL Database

## AWS Services

The current implementation uses:

### Networking and Traffic Management

- **Amazon VPC** - isolated project network with public and private subnets
- **Application Load Balancer (ALB)** - public entry point for the UI and API Gateway
- **AWS Load Balancer Controller** - provisions and manages the ALB from Kubernetes ingress resources

### Compute and Containers

- **Amazon EC2** - Jenkins Controller, Jenkins Agent, and SonarQube hosts
- **Amazon EBS** - persistent block storage for EC2 instances
- **Amazon ECR** - private Docker image repositories for application services
- **Amazon EKS** - managed Kubernetes control plane and worker nodes

### Database and Storage

- **Amazon RDS for MySQL** - managed application database
- **Amazon S3** - application attachments, Terraform remote state, and audit-log storage
- **AWS Secrets Manager** - managed database credential storage

### Identity and Security

- **AWS IAM** - roles, policies, instance profiles, and least-privilege service access
- **IAM Roles for Service Accounts (IRSA)** - pod-level AWS permissions for workloads such as the Attachment and Notification services

### Monitoring, Notifications, and Audit

- **Amazon CloudWatch** - infrastructure monitoring, alarms, and dashboarding
- **Amazon SNS** - alarm notifications
- **Amazon SES** - application email notifications
- **AWS CloudTrail** - AWS API activity auditing
- **AWS Budgets** - cloud cost monitoring and budget guardrails

Route 53 and AWS Certificate Manager are intentionally not part of the current implementation because the portfolio environment does not use a custom domain.

## DevOps Tooling

- **Git and GitHub** - source control and service repositories
- **Terraform** - AWS infrastructure provisioning and lifecycle management
- **Ansible** - configuration management for Jenkins and SonarQube hosts
- **Docker** - application containerization
- **Kubernetes** - workload orchestration on Amazon EKS
- **Helm** - installation and management of the AWS Load Balancer Controller
- **Jenkins** - CI/CD automation for application services
- **SonarQube** - static analysis, code-quality gates, and coverage validation
- **kubectl** - Kubernetes deployment and operational troubleshooting
- **AWS CLI** - AWS authentication, validation, and operational tasks

## Architecture Overview

The application follows a containerized microservices architecture running on Amazon EKS.

### Application Request Flow

```text
User Browser
     |
     v
Application Load Balancer
     |
     +----------------------+
     |                      |
     v                      v
Next.js UI             API Gateway
                            |
              +-------------+-------------+
              |             |             |
              v             v             v
          Auth Service  Ticket Service  Other Services
                                      /       |        \
                               Comment   Notification   Attachment
                                             |             |
                                             v             v
                                         Amazon SES     Amazon S3

Database-backed services
          |
          v
Amazon RDS for MySQL
```

The public ALB is created by the AWS Load Balancer Controller from Kubernetes ingress resources. The UI and API Gateway share the ALB, while backend services remain internal Kubernetes services.

Authentication is validated at the API Gateway, which forwards verified user identity context to downstream services. Service-level authorization protects administrative operations, ticket ownership and assignment, and attachment access.

The Attachment service uses IRSA to access its private S3 bucket without storing AWS access keys inside the application. The Notification service similarly uses AWS permissions to send application email through Amazon SES.

## CI/CD Flow

```text
Developer
   |
   v
GitHub
   |
   v
Jenkins Controller
   |
   v
Jenkins Agent
   |
   +--> Build / Test
   |
   +--> SonarQube Analysis
   |
   +--> Quality Gate
   |
   +--> Docker Build
   |
   +--> Push Image to Amazon ECR
   |
   +--> Deploy to Amazon EKS
   |
   v
Kubernetes Rollout Verification
```

Each application pipeline validates the service before deployment and verifies that the expected container image is running in EKS after rollout.

Terraform is responsible for infrastructure provisioning, while Ansible configures the supporting DevOps hosts. Routine environment startup and shutdown are handled separately through operational scripts rather than repeatedly running Terraform or Ansible.

## Security Controls

Security hardening is implemented across the application, Kubernetes workloads, and AWS infrastructure.

### Authentication and Authorization

- JWT authentication is enforced at the API Gateway for protected application routes.
- Verified user identity and role context are forwarded to downstream services.
- Application roles include `ADMIN`, `AGENT`, and `USER`.
- Auth administrative endpoints enforce role-based access control.
- Ticket authorization restricts access based on administrator role, ticket ownership, or agent assignment.
- Attachment operations validate access to the associated ticket before allowing list, upload, or download operations.
- Attachment authorization fails closed when the Ticket service cannot validate access.

### AWS Access Control

- IAM roles and policies are scoped to the permissions required by each component.
- EC2 instances use IAM instance profiles instead of storing long-lived AWS credentials.
- Kubernetes workloads use IRSA for AWS service access.
- The Attachment service receives scoped S3 permissions through its Kubernetes service account.
- The Notification service receives scoped Amazon SES permissions through its Kubernetes service account.
- Database credentials are managed through AWS Secrets Manager.

### Storage Security

The attachment S3 bucket is configured with:

- S3 Block Public Access
- Bucket owner enforced object ownership
- server-side encryption
- TLS-only access policy
- scoped IAM access
- lifecycle management for attachment objects

### Application Log Hygiene

Sensitive authentication logging was removed from the API Gateway:

- decoded JWT claims are not written to application logs,
- bearer authorization headers are not written to application logs,
- authorization headers continue to be forwarded where required for service communication.

### Verified Authorization Behaviour

| Test | Expected Result | Verified |
| --- | ---: | :---: |
| Protected endpoint without authentication | `401` | ✅ |
| Student accesses own ticket | `200` | ✅ |
| Assigned agent accesses assigned ticket | `200` | ✅ |
| Administrator accesses ticket | `200` | ✅ |
| Student accesses another user's ticket | `403` | ✅ |
| Student lists another ticket's attachments | `403` | ✅ |
| Student uploads to another ticket | `403` | ✅ |
| Student downloads another ticket's attachment | `403` | ✅ |
| Gateway logs checked for JWT/Bearer output | No sensitive authentication logging | ✅ |

## Observability, Audit, and Cost Controls

### Monitoring and Alerting

- Amazon CloudWatch is used for infrastructure metrics, dashboards, and alarms.
- CloudWatch alarms provide visibility into important AWS resource conditions.
- Amazon SNS is integrated with monitoring so alarm notifications can be delivered outside the AWS console.
- Application and Kubernetes health are also validated through service health checks and deployment rollout verification.

### Audit Logging

- AWS CloudTrail records AWS API activity for operational and security auditing.
- CloudTrail logs are delivered to a dedicated S3 audit bucket.
- Audit storage is separated from application attachment storage.

### Cost Controls

This environment is designed as a hands-on portfolio lab, so resources are scaled down when they are not required.

The operational shutdown workflow:

- removes Kubernetes ingress resources so the public ALB can be deleted,
- scales the EKS managed node group to zero workers,
- stops the RDS database,
- stops Jenkins Controller, Jenkins Agent, and SonarQube EC2 instances.

The startup workflow reverses these actions and dynamically discovers current runtime addresses.

AWS Budgets provides an additional cost-monitoring guardrail.

Stopping the lab reduces compute and load-balancer costs but does not make the AWS account completely cost-free. Persistent resources such as the EKS control plane, EBS volumes, RDS storage, S3 objects, ECR images, Secrets Manager secrets, and monitoring or audit data can continue to generate charges.

## Region

Asia Pacific (Hyderabad)

`ap-south-2`

## Project Status

The core AWS DevOps implementation is complete and has been validated in the running environment.

Implemented and verified:

- AWS networking and infrastructure provisioned with Terraform
- Jenkins Controller, Jenkins Agent, and SonarQube configured with Ansible
- application containers stored in Amazon ECR
- microservices deployed to Amazon EKS
- Application Load Balancer ingress routing
- Amazon RDS for MySQL integration
- private Amazon S3 attachment storage using IRSA
- Amazon SES application email delivery
- Jenkins CI/CD pipelines with SonarQube quality gates
- JWT authentication and role-based authorization
- ticket ownership and agent-assignment authorization
- attachment list, upload, and download authorization
- CloudWatch monitoring and alarms
- SNS notifications
- CloudTrail audit logging
- AWS budget guardrails
- automated daily startup, status, and shutdown workflows
- automated live-environment smoke testing

The remaining work is primarily final documentation and portfolio/demo polish.

## Automated Smoke Testing

A read-only smoke test validates the live AWS environment after startup:

```bash
./scripts/smoke-test.sh
```

The smoke test verifies:

- runtime configuration is available,
- the public UI is reachable through the Application Load Balancer,
- Gateway health and readiness endpoints return HTTP 200,
- the Kubernetes API and application namespace are reachable,
- all EKS worker nodes are Ready,
- all application deployments are Available,
- application pods are in healthy states,
- all containers inside Running pods are Ready.

The script exits with a non-zero status if any validation fails, making it useful for operational checks and future CI/CD integration.

A successful validation currently produces:

```text
Passed: 9
Failed: 0

SMOKE TEST PASSED
```

## Daily Environment Operations

The environment is intentionally started only when needed and scaled down afterward to reduce unnecessary AWS cost.

### Start

```bash
aws login
./scripts/start-i27.sh
```

The startup script:

1. starts Jenkins Controller, Jenkins Agent, and SonarQube EC2 instances,
2. starts Amazon RDS,
3. scales the EKS managed node group from zero to one worker,
4. restores the Kubernetes ingress resources,
5. waits for the application components,
6. discovers the current EC2 addresses and ALB DNS name.

Current runtime values are written to:

```text
runtime/i27-current.env
```

This file is excluded from Git because public IP addresses and the ALB DNS name can change between startups.

### Status

```bash
./scripts/status-i27.sh
```

The status script provides a quick operational view of the main AWS and Kubernetes components used by the environment.

### Stop

```bash
./scripts/stop-i27.sh
```

The shutdown script:

1. removes the public Kubernetes ingress resources so the ALB can be deleted,
2. scales the EKS managed node group to zero workers,
3. stops Amazon RDS,
4. stops Jenkins Controller, Jenkins Agent, and SonarQube EC2 instances.

Terraform and Ansible are not part of routine daily startup and shutdown.

- **Terraform** is used when AWS infrastructure must be provisioned or changed.
- **Ansible** is used when DevOps server configuration must be installed or changed.
- **Operational scripts** handle the normal daily lab lifecycle.

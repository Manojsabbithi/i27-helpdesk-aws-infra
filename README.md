# i27 Helpdesk - AWS DevOps Project

End-to-end AWS DevOps implementation for the i27 Helpdesk microservices application.

## Goal

Build the complete infrastructure and CI/CD platform from scratch using AWS and modern DevOps tooling.

## Application Services

- Next.js UI
- Node.js API Gateway
- Spring Boot Auth Service
- Spring Boot Ticket Service
- FastAPI Comment Service
- FastAPI Notification Service
- MySQL Database

## AWS Services

The project will use:

- IAM
- VPC
- EC2
- EBS
- Amazon ECR
- Amazon EKS
- Amazon RDS for MySQL
- Amazon S3
- AWS Secrets Manager
- AWS Systems Manager Parameter Store
- Application Load Balancer
- Route 53
- AWS Certificate Manager
- CloudWatch
- SNS
- SES
- CloudTrail
- AWS Budgets

## DevOps Tools

- Git / GitHub
- Terraform
- Ansible
- Docker
- Kubernetes
- Helm
- Jenkins
- SonarQube

## Region

Asia Pacific (Hyderabad)

`ap-south-2`

## Project Status

Infrastructure build in progress.

## Daily Environment Operations

### Start

```bash
aws login
./scripts/start-i27.sh
```

Starts the three DevOps EC2 instances, RDS, scales EKS workers from 0 to 1, recreates the ALB ingresses, waits for the application, and dynamically discovers the current EC2 public/private IP addresses and ALB DNS name.

### Status

```bash
./scripts/status-i27.sh
```

Current runtime addresses are written to `runtime/i27-current.env`. This file is excluded from Git because public IP addresses and the ALB DNS name can change between startups.

### Stop

```bash
./scripts/stop-i27.sh
```

Deletes the public ingresses/ALB, scales EKS workers to 0, stops RDS, and stops Jenkins Controller, Jenkins Agent, and SonarQube EC2 instances.

Terraform and Ansible are used for provisioning and configuration changes, not routine daily startup and shutdown.

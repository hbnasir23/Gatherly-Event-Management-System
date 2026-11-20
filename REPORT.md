# Gatherly — Technical Report

**Course:** Cloud Computing
**Project:** Gatherly — Event Management System
**Date:** 20 November 2026
**Live site:** https://gatherly-one-jet.vercel.app (auto-deployed by Vercel on every push to `main`)

---

## 1. Introduction

Gatherly is a cloud-ready web front end for an event management platform. The aim of the project is to show the full cloud delivery path for a containerised application:

- the application packaged as a **Docker** image
- the AWS infrastructure described as code with **Terraform**
- a **GitHub Actions** CI/CD pipeline that tests, builds, validates and (optionally) deploys on every push

The application itself is deliberately small: one page with a title, a heading and two action buttons ("Explore Events", "Register Now"). This keeps the focus on the cloud and DevOps parts.

## 2. Architecture

```
            Internet
               │  HTTP :80
               ▼
   ┌──────────────────────────┐
   │ Application Load Balancer│  public subnets in 2 AZs, SG: 80 from 0.0.0.0/0
   └────────────┬─────────────┘
                │  health check: GET /healthz
                ▼
   ┌──────────────────────────┐
   │ ECS Fargate service      │  2–4 tasks (CPU target tracking 60 %)
   │  Nginx container         │  SG: 80 from ALB security group only
   └────────────┬─────────────┘
                │ image pulled from          logs sent to
                ▼                            ▼
          Amazon ECR                 CloudWatch Logs (/ecs/gatherly-web)
```

| Layer | AWS service | Terraform file |
|---|---|---|
| Network | VPC 10.20.0.0/16, 2 public subnets, Internet Gateway, route table | `network.tf` |
| Security | ALB security group, web task security group (ALB-only ingress) | `security_groups.tf` |
| Load balancing | Application Load Balancer, target group (IP), HTTP listener | `load_balancer.tf` |
| Compute | ECS cluster, Fargate task definition (0.25 vCPU / 512 MB), ECS service | `ecs.tf` |
| Registry | ECR repository with scan-on-push | `ecs.tf` |
| Scaling | Application Auto Scaling, target tracking on CPU | `ecs.tf` |
| Monitoring | CloudWatch log group, Container Insights | `ecs.tf` |
| IAM | Task execution role with `AmazonECSTaskExecutionRolePolicy` | `ecs.tf` |

**Design decisions**

- **Fargate** instead of EC2: no servers to patch, and you pay per task.
- **Two availability zones**: the ALB needs them, and the service keeps running if one zone fails.
- **Least-privilege networking**: tasks accept traffic only from the load balancer's security group.
- **Health endpoint** `/healthz`: used by the Docker `HEALTHCHECK`, the ALB target group and the pipeline.

## 3. Containerisation (Docker)

`Dockerfile`:

- Base image `nginx:1.27-alpine` (small, about 20 MB)
- Copies `app/` into the Nginx web root
- Writes an Nginx config with a `/healthz` endpoint that returns `200 ok`
- `HEALTHCHECK` every 30 s

Local run: `docker compose up --build`, then open `http://localhost:8080`.

## 4. Infrastructure as Code (Terraform)

All resources are defined in `infra/terraform/`. Input variables (`variables.tf`): `aws_region`, `project`, `vpc_cidr`, `image_tag`, `desired_count`, `max_count`. The pipeline passes `image_tag` so each deploy runs the exact image built from that commit.

Outputs (`outputs.tf`): `app_url` (ALB DNS name), `ecr_repository_url`, `ecs_cluster_name`, `ecs_service_name`.

Every resource is tagged `Project=gatherly`, `ManagedBy=terraform` through the provider's `default_tags`.

## 5. CI/CD Pipeline (GitHub Actions)

File: `.github/workflows/ci-cd.yml`. It is triggered on push to `main`, on pull requests, and manually (`workflow_dispatch`).

| Job | Depends on | What it does |
|---|---|---|
| `test` | – | Runs `tests/smoke.sh`: checks the title, heading and at least two buttons |
| `build` | test | Builds the Docker image, starts it, checks `/healthz` and that the page contains the Gatherly heading |
| `terraform` | test | `terraform init -backend=false` + `terraform validate` |
| `deploy` | build, terraform | Creates ECR, pushes the image tagged with the commit SHA, runs `terraform apply`, prints the URL |

The `deploy` job runs only when the repository variable `DEPLOY_ENABLED` is `true` and AWS credentials are stored as GitHub secrets. Without them the pipeline still runs test, build and validate on every change, so it never fails just because no cloud account is attached.

**Demonstration:** change the text of a button in `app/index.html`, commit and push. The Actions tab shows the pipeline start, the smoke test check the page, and the Docker image build and serve the updated page.

## 6. Cost Estimate (us-east-1, monthly, approximate)

| Item | Assumption | Cost |
|---|---|---|
| Fargate | 2 tasks × 0.25 vCPU / 0.5 GB × 730 h | ≈ $18 |
| Application Load Balancer | 1 ALB + low LCU usage | ≈ $17 |
| Public IPv4 addresses | 2 tasks + 2 ALB IPs × $0.005/h | ≈ $15 |
| ECR | < 1 GB stored | ≈ $0.10 |
| CloudWatch Logs | < 1 GB, 7-day retention | ≈ $0.50 |
| **Total** | | **≈ $50 / month** |

Run `terraform destroy` after a demo to stop all charges.

## 7. Deployment Status

| Item | Status |
|---|---|
| Docker image builds and serves the page | Verified by the `build` job on every push |
| Terraform configuration | Verified by the `terraform validate` job on every push |
| AWS deployment of Gatherly | Defined and ready (`terraform apply` / `deploy` job); runs once AWS credentials are added |

## 8. Relation to the Eventra Project

Gatherly reuses the cloud design from our earlier **Eventra** project (https://github.com/AunZaidii/Eventra-Event-Management-System): ALB → ECS Fargate → managed services, Terraform-managed, deployed by GitHub Actions. Eventra *was* deployed to AWS. Its CLI and console evidence (VPC, subnets, ALB target health, ECS tasks, autoscaling, CloudWatch, load test) is reproduced in **Appendix A** of this report. It shows the same deployment approach working end to end. Those screenshots belong to the Eventra deployment and are referenced here as supporting evidence for the approach, not as screenshots of Gatherly.

## 9. Conclusion

Gatherly shows a complete cloud delivery workflow for a containerised web app: a Docker image with health checks, a Terraform-defined AWS environment with load balancing, autoscaling and logging, and a CI/CD pipeline that checks every change automatically and can deploy it to AWS.

---

## Appendix A — AWS Deployment Evidence (Eventra deployment)

> **Note:** The screenshots below come from the AWS deployment of our **Eventra** project, which uses the same cloud design that Gatherly's Terraform follows (VPC → ALB → ECS Fargate → ECR, with autoscaling and CloudWatch). Resource names in the screenshots therefore say `eventra`. They show the deployment approach working end to end on real AWS infrastructure.

### A.1 Architecture

**Architecture diagram**

![Architecture diagram](docs/evidence-eventra/architecture.png)

### A.2 Identity and Networking

**AWS identity used for deployment**

![AWS identity used for deployment](docs/evidence-eventra/00-identity.png)

**VPC**

![VPC](docs/evidence-eventra/01-vpc.png)

**Subnets across two availability zones**

![Subnets across two availability zones](docs/evidence-eventra/02-subnets.png)

**Route tables**

![Route tables](docs/evidence-eventra/03-route-tables.png)

**Internet gateway**

![Internet gateway](docs/evidence-eventra/04-internet-gateway.png)

**NAT instance**

![NAT instance](docs/evidence-eventra/05-nat-instance.png)

**Security groups**

![Security groups](docs/evidence-eventra/06-security-groups.png)

### A.3 Load Balancer

**Application Load Balancer**

![Application Load Balancer](docs/evidence-eventra/08-load-balancer.png)

**Target health (all targets healthy)**

![Target health (all targets healthy)](docs/evidence-eventra/10-target-health.png)

### A.4 Containers (ECR + ECS Fargate)

**Docker image build**

![Docker image build](docs/evidence-eventra/docker-build.png)

**ECR repositories**

![ECR repositories](docs/evidence-eventra/15-ecr-repositories.png)

**ECR images**

![ECR images](docs/evidence-eventra/16-ecr-images.png)

**ECS services**

![ECS services](docs/evidence-eventra/11-ecs-services.png)

**ECS running tasks**

![ECS running tasks](docs/evidence-eventra/12-ecs-tasks.png)

### A.5 Database, Secrets and IAM

**RDS PostgreSQL**

![RDS PostgreSQL](docs/evidence-eventra/14-rds.png)

**Database not publicly accessible**

![Database not publicly accessible](docs/evidence-eventra/21-db-not-public.png)

**Secrets Manager**

![Secrets Manager](docs/evidence-eventra/17-secrets.png)

**IAM deploy role used by GitHub Actions**

![IAM deploy role used by GitHub Actions](docs/evidence-eventra/18-iam-deploy-role.png)

### A.6 Health Check

**Health check endpoint through the load balancer**

![Health check endpoint through the load balancer](docs/evidence-eventra/20-health-check.png)

### A.7 Autoscaling and Load Test

**Autoscaling configuration**

![Autoscaling configuration](docs/evidence-eventra/13-autoscaling.png)

**Load test traffic**

![Load test traffic](docs/evidence-eventra/22-load-test-traffic.png)

**Autoscaling timeline**

![Autoscaling timeline](docs/evidence-eventra/23-autoscaling-timeline.png)

**Scaling activities**

![Scaling activities](docs/evidence-eventra/25-scaling-activities.png)

### A.8 Monitoring (CloudWatch)

**CloudWatch alarms and dashboard**

![CloudWatch alarms and dashboard](docs/evidence-eventra/19-cloudwatch.png)

**ECS CPU utilisation**

![ECS CPU utilisation](docs/evidence-eventra/cw-ecs-cpu.png)

**Healthy hosts**

![Healthy hosts](docs/evidence-eventra/cw-healthy-hosts.png)

**Request count**

![Request count](docs/evidence-eventra/cw-requests.png)

**Container logs**

![Container logs](docs/evidence-eventra/24-cloudwatch-logs.png)

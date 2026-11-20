# Gatherly — Event Management System

A containerised web front end for an event platform, with infrastructure as code (Terraform, AWS) and a GitHub Actions CI/CD pipeline.

## Project structure

```
app/index.html               Web page (title, heading, two action buttons)
Dockerfile                   Nginx image serving the page + /healthz endpoint
docker-compose.yml           One-command local run
tests/smoke.sh               Static checks run by the pipeline
infra/terraform/*.tf         AWS infrastructure: VPC, subnets, ALB, ECS Fargate, ECR, autoscaling, CloudWatch
.github/workflows/ci-cd.yml  CI/CD pipeline
REPORT.md                    Technical report
```

## Run locally

```bash
docker compose up --build
# open http://localhost:8080   (health check: http://localhost:8080/healthz)
```

## CI/CD pipeline

Every push to `main` runs:

1. **Test**: `tests/smoke.sh` checks the page has its title, heading and buttons
2. **Build**: builds the Docker image, starts the container and checks it responds
3. **Terraform validate**: `terraform init -backend=false && terraform validate`
4. **Deploy** (optional): pushes the image to ECR and runs `terraform apply`. It runs only when the repository variable `DEPLOY_ENABLED=true` and the secrets `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` are set.

To see the pipeline work, change the text in `app/index.html`, commit, push, and open the **Actions** tab.

## Deploy to AWS manually

```bash
cd infra/terraform
terraform init
terraform apply          # prints app_url when finished
```

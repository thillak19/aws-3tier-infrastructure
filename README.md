# 3-Tier AWS Infrastructure with Terraform

A modular, production-pattern AWS infrastructure (network, compute, database) provisioned entirely through Infrastructure as Code. Built as a hands-on project to apply real cloud engineering practices: layered security, remote state management, least-privilege IAM, and cost-conscious architecture decisions.

## Architecture

Internet traffic reaches an EC2 Auto Scaling Group in public subnets, which connects to a private RDS PostgreSQL database. Each layer is gated by its own security group, allowing only the traffic it needs from the layer directly in front of it.

```
Internet
   |
Internet Gateway
   |
Public Subnets (2 AZs) -- EC2 Auto Scaling Group (t3.micro, Apache)
   |
Private Subnets (2 AZs) -- RDS PostgreSQL (db.t3.micro)
```

**Security group chain:** ALB SG -> EC2 SG -> RDS SG, each scoped to accept traffic only from the layer before it (with a direct-internet HTTP rule on EC2 substituting for the ALB, see Design Decisions below).

## Tech stack

| Layer | Service |
|---|---|
| Networking | VPC, public/private subnets, Internet Gateway, route tables |
| Compute | EC2 Auto Scaling Group with Launch Template |
| Database | RDS PostgreSQL (private subnet, no public access) |
| Security | Security Groups (layered), custom least-privilege IAM policy |
| Secrets | AWS SSM Parameter Store (SecureString) |
| State management | Remote backend: S3 (versioned) + DynamoDB (locking) |
| IaC tool | Terraform, modular structure |

## Project structure

```
aws-3tier-infra/
├── backend.tf              # Remote state config (S3 + DynamoDB)
├── providers.tf            # AWS provider configuration
├── variables.tf            # Root-level input variables
├── main.tf                 # Root module, wires submodules together
├── outputs.tf               # Outputs (e.g. RDS endpoint)
├── terraform.tfvars        # Local variable values (gitignored)
└── modules/
    ├── vpc/                 # VPC, subnets, routing
    ├── security/             # Security groups (ALB, EC2, RDS)
    ├── rds/                  # PostgreSQL database
    ├── ec2/                  # Launch template + Auto Scaling Group
    └── alb/                  # Application Load Balancer (see note below)
```

## Design decisions

**No NAT Gateway.** RDS sits in a private subnet but does not require outbound internet access, so a NAT Gateway (~$32/month if left running) was deliberately omitted. EC2 instances run in public subnets instead, with security groups controlling access.

**ALB coded but not deployed.** The `modules/alb` directory contains a complete, validated (`terraform plan`-verified) Application Load Balancer configuration. It was not applied in the final deployment to keep the project fully free-tier — ALB is not free-tier eligible (~$0.025/hour). In its place, the EC2 security group includes a direct HTTP rule from the internet. This was a deliberate cost-vs-completeness tradeoff, not an oversight.

**Least-privilege IAM.** The deploying IAM user runs on a custom-scoped policy (`iam-policy.json`) covering only the specific actions this project needs (EC2, RDS, Auto Scaling, ELB, S3/DynamoDB for state, SSM for secrets) — verified by removing all AWS managed `FullAccess` policies and re-running `terraform plan`/`apply` successfully on the custom policy alone.

**Secrets via SSM Parameter Store**, not plaintext `.tfvars`. The RDS master password is stored as a `SecureString` in AWS Systems Manager Parameter Store and read at plan/apply time via a Terraform data source — never committed to version control.

**Remote state with locking.** Terraform state lives in a versioned S3 bucket, with DynamoDB providing state locking to prevent concurrent modification conflicts — the standard pattern for any multi-person or CI-driven Terraform workflow.

## Deployment

```bash
terraform init
terraform plan
terraform apply
```

To tear down (recommended after each session to avoid charges outside free-tier limits):

```bash
terraform destroy
```

## Verification

- EC2 instance serves a live page confirming successful provisioning and Apache install via `user_data`.
- RDS instance reachable from EC2 within the VPC; confirmed `Available` in AWS Console.
- All resources free-tier eligible (`t3.micro` EC2, `db.t3.micro` RDS) when run within AWS free-tier limits.

## What I'd add with more time/budget

- Apply the ALB module and add HTTPS via ACM
- CloudWatch alarms for CPU/connection thresholds
- Multi-environment setup (Terraform workspaces for dev/prod)
- CI/CD pipeline running `terraform fmt`, `validate`, and `plan` on pull requests
- Load testing to validate Auto Scaling Group behavior under traffic

## Author

Thillak K — B.E. Computer Science & Engineering (IoT), Sri Krishna College of Technology

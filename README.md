# 3-Tier AWS Infrastructure with Terraform

A modular, production-pattern AWS infrastructure (network, compute, database, load balancing, monitoring) provisioned entirely through Infrastructure as Code. Built as a hands-on project to apply real cloud engineering practices: layered security, remote state management, least-privilege IAM, automated CI/CD, and cost-conscious architecture decisions.

## Architecture

Internet traffic reaches an Application Load Balancer, which forwards to an EC2 Auto Scaling Group in public subnets, which connects to a private RDS PostgreSQL database. Each layer is gated by its own security group, allowing only the traffic it needs from the layer directly in front of it. CloudWatch alarms monitor CPU and connection health across compute and database tiers.

```
Internet
   |
Internet Gateway
   |
Application Load Balancer (public subnets, 2 AZs)
   |
EC2 Auto Scaling Group (t3.micro, Apache) -- public subnets
   |
Private Subnets (2 AZs) -- RDS PostgreSQL (db.t3.micro)
```

**Security group chain:** ALB SG -> EC2 SG -> RDS SG, each scoped to accept traffic only from the layer before it. SSH access is restricted to a single known IP (`/32`), not open to the internet.

## Tech stack

| Layer | Service |
|---|---|
| Networking | VPC, public/private subnets, Internet Gateway, route tables |
| Load balancing | Application Load Balancer, target group, health checks |
| Compute | EC2 Auto Scaling Group with Launch Template |
| Database | RDS PostgreSQL (private subnet, no public access) |
| Security | Security Groups (layered), custom least-privilege IAM policy, SSH locked to a single IP |
| Monitoring | CloudWatch alarms (EC2 CPU, RDS CPU, RDS connections) |
| Secrets | AWS SSM Parameter Store (SecureString) |
| State management | Remote backend: S3 (versioned) + DynamoDB (locking) |
| CI/CD | GitHub Actions — `terraform fmt`, `validate`, `plan` on every push |
| IaC tool | Terraform, modular structure |

## Project structure

```
aws-3tier-infra/
├── .github/workflows/
│   └── terraform.yml       # CI pipeline: fmt, validate, plan
├── backend.tf              # Remote state config (S3 + DynamoDB)
├── providers.tf            # AWS provider configuration
├── variables.tf            # Root-level input variables
├── main.tf                 # Root module, wires submodules together
├── outputs.tf               # Outputs (RDS endpoint, ALB URL)
├── iam-policy.json         # Custom least-privilege IAM policy
├── terraform.tfvars        # Local variable values (gitignored)
└── modules/
    ├── vpc/                 # VPC, subnets, routing
    ├── security/             # Security groups (ALB, EC2, RDS)
    ├── rds/                  # PostgreSQL database
    ├── ec2/                  # Launch template + Auto Scaling Group
    ├── alb/                  # Application Load Balancer, target group, listener
    └── monitoring/            # CloudWatch alarms
```

## Design decisions

**No NAT Gateway.** RDS sits in a private subnet but does not require outbound internet access, so a NAT Gateway (~$32/month if left running) was deliberately omitted. EC2 instances run in public subnets instead, with security groups controlling access.

**ALB deployed and verified live.** The full Application Load Balancer — load balancer, target group, listener, and Auto Scaling attachment — was applied, tested against a live URL (`http://<alb-dns-name>`), confirmed healthy in the target group, and then torn down to control free-tier cost. The architecture is proven end-to-end, not just plan-verified.

**Least-privilege IAM, built iteratively through real usage.** The deploying IAM user runs on a custom-scoped policy (`iam-policy.json`), refined across multiple revisions by deploying the full stack, observing exactly which AWS API calls were denied, and adding only those specific permissions — covering EC2, Auto Scaling, RDS, ELB, CloudWatch, S3/DynamoDB for state, and SSM for secrets. Verified by removing all AWS managed `FullAccess` policies and successfully running the complete `plan`/`apply`/`destroy` lifecycle on the custom policy alone.

**CloudWatch monitoring.** Alarms track EC2 CPU utilization, RDS CPU utilization, and RDS connection count, each evaluated over two 5-minute periods before triggering — basic but functional operational visibility. (Not yet wired to SNS for notifications; alarm state is visible in-console.)

**Secrets via SSM Parameter Store**, not plaintext `.tfvars`. The RDS master password is stored as a `SecureString` in AWS Systems Manager Parameter Store and read at plan/apply time via a Terraform data source — never committed to version control.

**Remote state with locking.** Terraform state lives in a versioned S3 bucket, with DynamoDB providing state locking to prevent concurrent modification conflicts — the standard pattern for any multi-person or CI-driven Terraform workflow.

**CI/CD on every push.** A GitHub Actions workflow runs `terraform fmt -check`, `terraform init`, `terraform validate`, and `terraform plan` automatically, catching formatting issues or invalid configuration before any manual `apply`.

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

- ALB-fronted EC2 instance served a live page (`Hello from <hostname>`) at the load balancer's public DNS name; target group reported the instance as healthy.
- RDS instance reachable from EC2 within the VPC; confirmed `Available` in AWS Console.
- CloudWatch alarms created and visible in-console for EC2 and RDS CPU, and RDS connection count.
- CI pipeline passing on every push: format check, init, validate, and plan all green.
- All compute/database resources free-tier eligible (`t3.micro` EC2, `db.t3.micro` RDS); ALB was deployed briefly for verification, then destroyed, since it is not free-tier eligible.

## What I'd add with more time/budget

- **HTTPS via ACM** — requires a registered domain name to issue a certificate; the ALB and listener are already structured to support this addition
- **Multi-environment setup** (Terraform workspaces or separate state per dev/prod)
- **Load testing** to observe and confirm Auto Scaling Group scale-out behavior under real traffic
- **Multi-AZ RDS** for database failover (currently single-AZ to stay within free tier)
- **SNS notifications** wired to the existing CloudWatch alarms

## Author

Thillak K — B.E. Computer Science & Engineering (IoT), Sri Krishna College of Technology

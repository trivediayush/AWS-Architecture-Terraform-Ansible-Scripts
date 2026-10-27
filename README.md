# AWS Terraform + Ansible package (Excel scope only)

This package represents the agreed baseline from the supplied task tracker and estimate excerpt. It does **not** apply infrastructure automatically.

## Included components

| Folder | Independent state/root | Scope |
|---|---|---|
| `bootstrap` | Yes (local only) | S3 remote-state bucket (versioned, encrypted, public-blocked). Run once, first. |
| `components/00-network` | Yes | VPC, 2 public subnets, 2 private app subnets, 2 DB subnets, IGW, per-AZ app route tables, NAT gateway(s). |
| `components/01-security-groups` | Yes | ALB, staging EC2, production ECS host and RDS security groups. Staging SSH limited to a supplied administrator CIDR; production hosts have no public SSH ingress. |
| `components/02-iam` | Yes | Staging EC2 role/profile (CloudWatch + scoped staging-S3), ECS instance role/profile, ECS task execution role (+ secret read), ECS task role (+ scoped prod-S3 and secret read). No SSM managed-instance policy — SSH/PEM only. |
| `components/03-staging-ec2` | Yes | One `t4g.medium`, 30 GB gp3 root volume, Amazon Linux 2023 ARM64, existing EC2 key pair (PEM) for SSH, IMDSv2. |
| `components/04-staging-s3` | Yes | Staging S3 bucket: encrypted, public-blocked, versioned, old-version expiry. |
| `components/05-production-s3` | Yes | Production S3 bucket: encrypted, public-blocked, versioned, old-version expiry. |
| `components/06-ecr` | Yes | Shared private ECR repository, immutable tags, scan on push, lifecycle policy (untagged 14 d / keep last 20). |
| `components/07-rds-multi-az` | Yes | Private PostgreSQL RDS Multi-AZ, 100 GB gp3 with storage autoscaling, managed master password, Performance Insights, backups and final snapshot. |
| `components/08-production-ecs-capacity` | Yes | Production ECS cluster (Container Insights) and two `c6g.xlarge` EC2 capacity nodes with 100 GB gp3 each. No staging ECS. |
| `components/09-production-alb` | Yes | Production ALB, `ip` target group, access-logs bucket. HTTPS/HTTP listeners are created only after an approved non-ACM IAM certificate ARN is supplied. |
| `components/10-cloudwatch` | Yes | Log groups; EC2/RDS/ALB/ECS alarms; optional SNS email notifications. |
| `components/11-production-ecs-service` | Yes | awsvpc task definition + ECS service wired to the ALB target group, deployment circuit breaker. Apply only once image/port/secrets are confirmed. |
| `ansible` | Separate runbooks | Minimal staging host baseline plus optional DB logical database/user bootstrap. |

## Explicitly not included

- No ACM, Route 53, EKS, Redis/Valkey, or CI/CD resources. DNS stays at the external provider; TLS uses an imported IAM server certificate.
- No SSM agent or Session Manager anywhere — access is SSH with an existing EC2 key pair (PEM), per decision. Staging inventory uses the instance public IP; production ECS hosts are private and need an approved VPN/bastion path for SSH.
- No application runtime on staging EC2 (deployment method unconfirmed); Ansible baseline only.

## Important blockers before apply

1. Confirm the shown staging EC2 configuration is actually the client's selected **Option 2**.
2. Confirm AWS account/region, AZ names, app port, app runtime, RDS instance class and PostgreSQL engine version.
3. NAT gateway is now **on by default** (`enable_nat_gateway = true`, one per AZ) because private ECS hosts cannot pull ECR images or register with ECS without egress — the estimate's NAT quantity zero does not work in practice. Set `single_nat_gateway = true` to halve NAT cost, or `enable_nat_gateway = false` only if approved VPC endpoints replace it.
4. TLS is not completed until the approved free certificate is imported into IAM and the ARN is supplied. Do not route production traffic before HTTPS is configured.
5. Confirm the RDS class/version and the database naming/user/secret lifecycle with the DB owner.
6. `components/11-production-ecs-service` needs a real pushed image, confirmed port/health path and secrets before apply — the ALB health check will mark targets unhealthy on placeholders.

## Remote state

Run `bootstrap/` first (see `bootstrap/README.md`), then uncomment the `backend "s3"` block in each component's `versions.tf` and `terraform init -migrate-state`. Each component keeps an independent state file under `components/<name>/terraform.tfstate`, so any component can be planned/applied/destroyed alone. Locking uses S3-native `use_lockfile` (Terraform >= 1.10), no DynamoDB table.

## Independent create/destroy behavior

Each `components/*` directory is a separate Terraform root with its own state. A component can be planned/applied/destroyed without a monolithic root. Cross-component inputs are wired automatically: leave a dependency tfvar empty and it is read from the upstream component's `terraform.tfstate` via `terraform_remote_state`; set it manually to override. Terraform will not automatically order cross-component creates/destroys — apply upstream first.

Example:

```bash
export AWS_PROFILE=approved-profile
export AWS_REGION=ap-south-1
terraform -chdir=components/00-network init
terraform -chdir=components/00-network fmt -recursive
terraform -chdir=components/00-network validate
terraform -chdir=components/00-network plan -var-file=terraform.tfvars
terraform -chdir=components/00-network apply -var-file=terraform.tfvars
```

Copy `example.tfvars.example` to `terraform.tfvars` in the relevant component and replace placeholders. Never commit real `terraform.tfvars`, `.tfstate`, `.tfstate.*`, secrets, or plan files.

### Suggested dependency order

Create: bootstrap → network → security groups → IAM → ECR → S3 → RDS → staging EC2 → production ECS capacity → ALB → ECS service → CloudWatch → Ansible runs after validation.

See `DEPLOYMENT.md` for the full dependency map, the staging-only apply path, and the manual console/CLI work these scripts do not cover.

Destroy in reverse dependency order. RDS is deliberately protected by default; to destroy it, obtain explicit approval, take/verify a backup, set `deletion_protection = false`, and use a unique `final_snapshot_identifier`. Do not destroy shared RDS just to remove one environment; staging/prod share it.

## Known implementation boundary

The ECS service (component 11) is the last manual gate: it needs a real image URI, confirmed container port, health endpoint and secret ARNs. Until it is applied the ALB target group has no targets — that is intentional, not an omission.

# Deployment guide: dependencies, staging-only path, manual work

## Component dependency map

Each row: what the component **needs** from earlier components. Inputs auto-resolve — when a dependency tfvar is left empty, a `terraform_remote_state` data source reads the value straight out of the upstream component's `terraform.tfstate` (local backend, sibling path). Filling the tfvar manually always overrides; that escape hatch is also the only path if a component's resources live somewhere else. Optional vars (02 bucket ARNs, 10 alarm inputs) stay manual — empty means "skip", not "auto-read".

Note: with the default local-state wiring, components must be applied under this `components/` tree so relative `../` paths resolve. After migrating to the S3 backend, switch each `terraform_remote_state` block's `backend = "local"`/`path` to `backend = "s3"` + bucket/key/region — it's marked with a `shortcut:` comment in each main.tf.

```
bootstrap              → nothing (run once, first)
00-network             → nothing
01-security-groups     → 00 (vpc_id)
02-iam                 → 04 (staging_bucket_arn), 05 (production_bucket_arn),
                          07 (task_secret_arns) — all optional, empty = skip
03-staging-ec2         → 00 (subnet_id), 01 (staging SG), 02 (staging profile)
04-staging-s3          → nothing
05-production-s3       → nothing
06-ecr                 → nothing
07-rds-multi-az        → 00 (db subnet ids), 01 (rds SG)
08-ecs-capacity        → 00 (app subnet ids), 01 (ecs SG), 02 (ecs instance profile)
09-production-alb      → 00 (vpc, public subnets), 01 (alb SG)
10-cloudwatch          → 03 (instance id), 07 (rds id), 09 (arn_suffixes),
                          08/11 (cluster/service names) — all optional
11-ecs-service         → 00 (app subnets), 01 (ecs SG), 02 (task + exec roles),
                          08 (cluster), 09 (target group), 10 (log group)
ansible                → applied infra (staging host, RDS endpoint)
```

Apply order: `bootstrap → 00 → 01 → 04+05+06 → 02 → 07 → 03 → 08 → 09 → 11 → 10 → ansible`

Destroy in reverse. Within the same tier order does not matter.

## Can I apply only staging for now?

Yes. The shared layer (VPC, SGs, IAM, RDS) is created once and serves both environments — that is the intended design. Apply only:

```
bootstrap → 00-network → 01-security-groups → 04-staging-s3
→ 02-iam (staging_bucket_arn filled, production_bucket_arn empty)
→ 07-rds-multi-az (only if staging needs the database now)
→ 03-staging-ec2
→ 10-cloudwatch (staging_instance_id only; other vars empty)
→ ansible/playbooks/staging-baseline.yml
```

Skip for now: `05-production-s3`, `06-ecr` (only if staging pulls container images), `08`, `09`, `11`. None of them interfere with staging — production pieces create nothing until applied.

Later, production = apply `05`, `06`, `08`, `09`, `11` and re-fill `02-iam` + `10-cloudwatch` vars. Staging keeps running; nothing overlaps because each component has its own state and resources are tagged `Environment`.

Caveat: staging and production share one VPC and one RDS instance by design (separate SGs, subnets, DBs, users). If the client later demands fully separate VPCs, you would re-apply `00`/`01` with a different `project_name`/CIDR — do not try to split the existing ones in place.

## What Terraform creates vs. what is left manual

### Created by these scripts

- S3 remote-state bucket (bootstrap)
- VPC, 6 subnets across 2 AZs, IGW, NAT gateway(s), route tables
- 4 security groups (ALB / staging / ECS / RDS), least-privilege rules
- IAM: staging instance profile, ECS instance profile, task execution role, task role, scoped S3/secret policies
- Staging EC2 `t3.medium` x86_64 on latest Amazon Linux 2023 (encrypted gp3, IMDSv2)
- Staging + production S3 buckets (encrypted, versioned, lifecycle)
- ECR repo (immutable tags, scan-on-push, lifecycle)
- RDS PostgreSQL Multi-AZ (encrypted, managed master password in Secrets Manager, backups, final snapshot, Performance Insights, storage autoscaling)
- ECS cluster + launch template + ASG (2× `c6g.xlarge`) + capacity provider, Container Insights
- ALB + `ip` target group + access-logs bucket (HTTPS listener only after cert ARN supplied)
- CloudWatch log group + alarms, production only (RDS CPU/storage, ALB 5xx/unhealthy, ECS CPU), optional SNS email topic
- ECS task definition + service (component 11, once image/port confirmed)

### Left for manual console / CLI work

| Task | Where |
|---|---|
| Key pair `sunroof-key` is already created in ap-south-1; keep `sunroof-key.pem` out of Git (`*.pem` is gitignored) and `chmod 400` it | EC2 console (done) |
| Import the free TLS certificate into IAM; copy the cert ARN into `09` tfvars | IAM → Server certificates |
| Point external DNS hostname (CNAME) at the ALB DNS name | External DNS provider (after 09) |
| Build, tag, push the app image to ECR | `aws ecr get-login-password` + docker (before 11) |
| Create app-level Secrets Manager secrets (app DB user creds) for `container_secrets`; add ARNs to `02-iam` | Secrets Manager |
| Confirm the SNS alarm email subscription | Link in the email (after 10) |
| Run Ansible: `staging-baseline.yml`, then `database-bootstrap.yml` to create `staging_app`/`production_app` DBs + users | Ansible, after infra validated |
| Retrieve the RDS master password when needed | Secrets Manager (RDS-managed secret) |
| CI/CD pipeline | Out of scope until approved — manual release process meanwhile |

No SSM/Session Manager anywhere — admin access is SSH + PEM only (staging via its public IP; production hosts are private and need an approved VPN/bastion path).

# Sunroof infrastructure

Three independent Terraform roots. Each has its own state and can be applied/destroyed alone.

| Root | Contents | Depends on |
|---|---|---|
| `shared/` | VPC, subnets, NAT, security groups, IAM roles/profiles, ECR repo, SNS alarm topic | nothing — apply first |
| `staging/` | Staging EC2, staging S3, staging IAM policy (no alarms/logs — test env) | `shared/` state |
| `prod/` | Production S3, RDS Multi-AZ Postgres, ECS cluster + ASG capacity, ALB + target group + listeners, ECS service, prod alarms | `shared/` state |

`staging/` and `prod/` never reference each other — destroy or rebuild either without touching the other.

## Apply

```bash
terraform -chdir=shared  init && terraform -chdir=shared  apply
terraform -chdir=staging init && terraform -chdir=staging apply
terraform -chdir=prod    init && terraform -chdir=prod    apply
```

All values are pinned in each root's `terraform.tfvars` — no `-var` flags needed.

## Known notes (learned during bring-up)

- **ap-south-1 t4g capacity is thin.** Staging is `t3.medium` x86_64, ECS nodes `c6g.xlarge` (Graviton), RDS `db.t3.medium`. If a create fails with `InsufficientInstanceCapacity`, retry later, drop a size, or change `subnet_id` (staging) to the other public subnet.
- **ALB runs HTTP-only until `certificate_arn` is set** in `prod/terraform.tfvars` (imported IAM server cert). Port 80 forwards to the app meanwhile; with a cert it becomes a 443 listener + 80→443 redirect automatically.
- **RDS destroy takes a final snapshot** (`final_snapshot_identifier`) and `deletion_protection` must be flipped to `false` first.
- **ALB access-log bucket** won't destroy while non-empty — empty it first or set `access_logs_force_destroy = true`.

## After terraform apply — manual steps

Terraform stops at infrastructure. These remain manual/console:

1. **Confirm the SNS subscription.** If `alarm_email` was set, the email address gets an "AWS Notification — Subscription Confirmation" email — click confirm or alarms notify nobody.
2. **SSH to staging** (only entry point; prod hosts are private, no public SSH):
   `ssh -i <sunroof-key.pem> ec2-user@<staging public_ip from outputs>` — works only from the `admin_ssh_cidr` IP.
3. **Baseline the staging host:** `sudo dnf update -y && sudo dnf install -y curl jq unzip chrony postgresql15 && sudo systemctl enable --now chronyd` (psql client needed for step 5).
4. **Fetch DB master creds:** `terraform -chdir=prod output -raw master_secret_arn` → `aws secretsmanager get-secret-value --secret-id <arn> --region ap-south-1 --query SecretString --output text` (JSON with `username`/`password`).
5. **Create the logical DBs/users** — run from the staging host (it's inside the VPC; RDS has no public endpoint):
   ```bash
   psql "host=<db_endpoint> user=sunroof_admin password=<from step 4> dbname=staging_app sslmode=verify-full sslrootcert=<rds ca bundle>"
   # then: CREATE DATABASE production_app;
   #       CREATE USER <staging_user>  WITH PASSWORD '...'; GRANT CONNECT ON DATABASE staging_app    TO <staging_user>;
   #       CREATE USER <prod_user>     WITH PASSWORD '...'; GRANT CONNECT ON DATABASE production_app TO <prod_user>;
   ```
   RDS CA bundle: `curl -O https://truststore.pki.rds.amazonaws.com/ap-south-1/ap-south-1-bundle.pem`
6. **Push the app image to ECR** (`terraform -chdir=shared output repository_url`), then set `image_uri` in `prod/terraform.tfvars` and re-apply prod. Tags are immutable — new tag every deploy.
7. **HTTPS cutover:** import the approved certificate into IAM (Server certificates), put its ARN in `certificate_arn`, re-apply prod. Point DNS at the ALB DNS name (external DNS provider — no Route 53 in scope).

## Teardown

Reverse order: `prod` → `staging` → `shared`. For prod, first `-var="deletion_protection=false" -var="apply_immediately=true"` apply, then destroy. Empty the ALB log bucket if the destroy fails on `BucketNotEmpty`.

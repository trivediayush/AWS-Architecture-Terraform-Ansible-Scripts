# Remote state bootstrap

Creates the S3 bucket that stores Terraform state for every `components/*` root. Run this first, once, with local state — keep its tfstate somewhere safe (it is the only component whose state cannot live in the bucket it creates).

1. `terraform init && terraform apply -var-file=terraform.tfvars`
2. Take the output bucket name, fill `REPLACE_WITH_STATE_BUCKET` in the commented `backend "s3"` block inside each component's `versions.tf`, uncomment it.
3. `terraform init -migrate-state` inside each component to move local state into S3.

Locking uses the S3-native `use_lockfile` (Terraform >= 1.10); no DynamoDB table needed. Versioning on the bucket protects against state corruption/deletion.

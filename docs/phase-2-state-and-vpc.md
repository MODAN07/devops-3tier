# Phase 2: Remote state and VPC

## Goal
Create a safe place to store Terraform state, then build the network that every later phase sits on.

## Step 1: Bootstrap the state bucket

**What:** `infra/bootstrap` creates one S3 bucket named `devops3tier-tfstate-<account-id>`.

**Why it exists:** Terraform records what it built in a state file. If that file lives on your laptop, it can be lost, it can't be shared with CI, and two people can corrupt it by applying at once. Storing it in S3 fixes all three.

**Why the bucket is configured the way it is:**
- *Versioning:* lets you roll back a bad or corrupted state file.
- *Encryption:* state files contain resource IDs and sometimes secrets in plain text.
- *Public access block and TLS-only policy:* the state file is a map of your infrastructure, so it must never be readable from outside.
- *prevent_destroy:* a typo in `terraform destroy` should not delete your state.

**Why this is a separate config:** the bucket can't store its own state before it exists. This is the one chicken-and-egg step, so it runs once with local state and is then left alone.

```bash
cd infra/bootstrap
terraform init
terraform apply
```

Note the bucket name in the output.

## Step 2: Point the dev environment at the bucket

Open `infra/envs/dev/main.tf` and replace `<ACCOUNT_ID>` in the `backend "s3"` block with your 12-digit AWS account ID (`aws sts get-caller-identity --query Account --output text`). Backend blocks cannot use variables, so this one value is hard-coded.

**Locking:** `use_lockfile = true` is native S3 locking, available from Terraform 1.10. It stops two applies running at once. Older guides use a DynamoDB table for this; you don't need one.

## Step 3: The VPC module

**What it builds (2 AZs):**

| Tier | Subnets | Route to internet | Holds |
|---|---|---|---|
| Public | 10.0.0.0/24, 10.0.1.0/24 | Internet gateway | Load balancer, NAT gateway |
| Private | 10.0.10.0/24, 10.0.11.0/24 | Outbound only, via NAT | EKS worker nodes |
| Database | 10.0.20.0/24, 10.0.21.0/24 | None | RDS |

**Design choices to be able to defend:**
- *Database subnets have no default route.* Even a misconfigured security group can't expose the database to the internet, because there is no path.
- *Nodes sit in private subnets.* They reach the internet for image pulls through NAT, but nothing on the internet can reach them directly.
- *Single NAT gateway.* Cheaper for a lab (about $35 a month versus about $105 for three). The trade-off is that an AZ outage can cut off egress for the other AZ. Set `single_nat_gateway = false` for production.
- *Default security group is emptied.* The VPC default allows all traffic between its members; stripping the rules means nothing can rely on it by accident.
- *Flow logs to CloudWatch (14 days).* A network audit trail, and a talking point for a security role.
- *Kubernetes subnet tags.* `kubernetes.io/role/elb` and `internal-elb` tell the AWS Load Balancer Controller which subnets to use. Without them, ingress silently fails later.

## Step 4: Plan and apply

```bash
cd infra/envs/dev
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Read the plan before applying. You should see roughly 30 resources to add. The NAT gateway starts billing as soon as it exists.

## Cost note
The NAT gateway (about $0.045 per hour plus data) is the main cost in this phase. If you stop for the night, `terraform destroy` in `envs/dev` removes it. Do **not** destroy `infra/bootstrap`.

## Verify
- `terraform output` shows the VPC ID and six subnet IDs.
- In the AWS console, the database route table has only the `local` route.
- The state file appears in the S3 bucket under `envs/dev/terraform.tfstate`.

## Next: Phase 3, ECR and the OIDC role for GitHub Actions, then EKS.

# AEM-style AWS Multi-Environment Cloud Infrastructure Platform

Portfolio lab: production-style patterns, **not** an AEM-owned system. Infrastructure is a VPC plus 2 AZs × (public, app, database) subnet tiers; public internet routing; isolated database route tables; optional NAT; optional S3 gateway endpoint; separated dev/staging/prod root stacks; CI syntax validation.

## Architecture

Internet → IGW → public subnets (future internet-facing ALB) → private app subnets (future EC2/ASG) → isolated database subnets (future RDS).

The public subnet route table has `0.0.0.0/0 → IGW`, **but subnets do not automatically assign public IPs**. Private app route tables have local routes, optional NAT default routes, and optional S3 gateway routes. Database route tables have only local routes and no default internet route. The S3 endpoint does not provide general internet access, and without NAT or additional VPC endpoints private instances cannot obtain OS updates or access arbitrary APIs.

## Prerequisites

- Terraform >= 1.10, AWS CLI v2, valid AWS identity with EC2/VPC permissions, and `ca-central-1` region available.
- Use an AWS IAM role/profile (not hardcoded secrets). Set `AWS_PROFILE` if needed.
- Do not expect this networking-only phase to deploy an application, EC2, RDS, or monitoring alarms.

## Step 1: Inspect identity

```bash
aws sts get-caller-identity
aws configure get region
terraform version
```

## Step 2: Configure and deploy DEV only

```bash
cd environments/dev
terraform init
terraform fmt -check -recursive ../../
terraform validate
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
terraform output
```

The default dev config is 10.20.0.0/16 in `ca-central-1`, with two AZs, `nat_mode=none`, and an S3 gateway endpoint. Verify subnet IDs and route tables in the AWS VPC console. Only after reviewing your plan should you run `apply`.

## Step 3: Stage and prod (initially PLAN ONLY)

```bash
cd ../staging
terraform init && terraform validate && terraform plan
cd ../prod
terraform init && terraform validate && terraform plan
```

These are independently configured and **not deployed automatically**. The `prod` example defaults to `nat_mode=none` to avoid unexpected charges, but this is a learning baseline and not a production-complete network. Before actual production deployment, design resilient outbound routing (`per_az` NAT or appropriate network endpoints), logging, segmentation, backup/recovery, remote state, and separate AWS account governance.

## Step 4: Check / cleanup DEV

```bash
cd environments/dev
terraform output
terraform plan -destroy
terraform destroy
```

After cleanup, check for leftover billable resources. `terraform destroy` does NOT delete the future remote state bucket or objects, and charges from other resources may remain.

## Costs and safety

- No EC2, ALB, RDS, VPC interface endpoints, or NAT gateways are deployed by default.
- NAT gateways, when enabled, incur hourly and data-processing charges; public IPv4/EIP and internet data transfer can also be billed.
- S3 gateway endpoints don't have hourly gateway charges; traffic/storage charges may still apply.
- Set up AWS Budgets and review your account's actual charges. AWS Budgets notifications are not hard cost caps.
- Use the sample `scripts/create-state-bucket.sh` and instructions in `bootstrap-state/README.md` to migrate to remote state before team use or CI deployment. Never commit `.tfstate`, `backend.hcl`, access keys or saved plan files.
- Avoid applying staging or prod in the same AWS account unless you explicitly want three VPCs and their costs.

## Environment addressing

| Environment | VPC | Public /24s | Private app /24s | Isolated DB /24s |
|---|---|---|---|---|
| dev | 10.20.0.0/16 | 10.20.0.0, 10.20.1.0 | 10.20.10.0, 10.20.11.0 | 10.20.20.0, 10.20.21.0 |
| staging | 10.30.0.0/16 | 10.30.0.0, 10.30.1.0 | 10.30.10.0, 10.30.11.0 | 10.30.20.0, 10.30.21.0 |
| prod | 10.40.0.0/16 | 10.40.0.0, 10.40.1.0 | 10.40.10.0, 10.40.11.0 | 10.40.20.0, 10.40.21.0 |

## Roadmap

1. **This package:** networking module + environment roots + basic validation workflow.
2. Remote S3 backend with native `.tflock` locking, secure CI identity and account separation.
3. Security groups, EC2 IAM/SSM, app ALB and Auto Scaling.
4. CloudWatch logs and alerts, synthetic health checks and incident runbooks.
5. RDS optional module, encryption, recovery objectives and cost controls.

## Interview talking points

Explain why subnet tiers exist, why an IGW alone doesn't make an instance public, why database subnets have no default route, the reliability/cost tradeoff between no/single/per-AZ NAT, separate state per environment, and how you would productionize this network. Clearly label the repository as a demonstration project.

## Phase 2 addendum (November 2026)

- Detailed file and networking resource review: `docs/networking-review.md`.
- Bootstrap and S3 backend migration: `bootstrap-state/README.md`; encrypted/versioned bucket script: `scripts/create-state-bucket.sh`.
- Native S3 lockfiles in all environment `backend.hcl.example` templates. **Copy** both `backend.tf.example` and `backend.hcl.example` into active files to enable remote state.
- `bootstrap-state/iam-policy-template.json` is a deliberately scoped **example** IAM policy for one environment; not automatically installed.
- CI now checks formatting without mutating code, initializes without touching S3, runs `terraform validate`, and checks static design invariants.
- Execute dependency-free static tests locally: `python3 tests/test_network_design.py`.
- The repository package has been inspected and static-tested here; no authenticated AWS plan/apply has been performed.

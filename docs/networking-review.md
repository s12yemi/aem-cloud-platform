# Networking module walkthrough — interview notes

## What exists

`modules/networking/main.tf` is the resource graph: `aws_vpc`, `aws_internet_gateway`, six `aws_subnet` resources, a shared public route table and two private app/two isolated DB route tables, associations, optional NAT and an S3 gateway endpoint. `variables.tf` validates VPC CIDR (/16), two AZ names and NAT mode; `outputs.tf` exports IDs for future ALB/ASG/RDS modules; `versions.tf` pins minimum Terraform and AWS provider requirements.

Environment root files: `main.tf` selects two AWS AZs and invokes the shared module; `providers.tf` chooses `ca-central-1` and default tags; `variables.tf` sets per-environment CIDR; `outputs.tf` re-exports IDs; `versions.tf` sets Terraform/provider constraints; `terraform.tfvars.example` is optional customization; `backend.tf.example` and `backend.hcl.example` activate remote state after the bucket exists.

## Expected dev plan — no NAT

- 1 VPC + 1 Internet Gateway
- 6 subnets (2 public, 2 private application, 2 isolated database)
- 5 route tables (1 public, 2 app, 2 database)
- 6 associations
- 1 S3 gateway endpoint
- **20 resources created**, assuming existing state is empty and provider behavior unchanged. Terraform's real plan is authoritative.

Public route table includes `0.0.0.0/0 -> IGW`; app/database tables have VPC `local` route, and app tables receive S3 endpoint routes. The database tier has no default route. NAT disabled means no general outbound internet for private workloads. Security groups are not created yet; this module alone does not secure future application-to-database traffic. Note: public subnet does not grant public IPs by default (`map_public_ip_on_launch=false`).

## Useful commands

`terraform fmt -check -recursive` checks formatting without editing. `terraform init -backend=false` downloads provider/plugins without connecting to state. `terraform validate` checks internal configuration validity without accessing AWS. `terraform plan -out=tfplan` queries AWS, calculates changes and saves a potentially sensitive plan. `terraform show tfplan` makes it human-readable. `terraform state list` lists deployed resources in configured state. `terraform output` shows root outputs, after an apply.

For resources and topology in the live AWS account, inspect `aws ec2 describe-vpcs`, `describe-subnets`, `describe-route-tables`, and `describe-vpc-endpoints` using the intended profile/region; compare actual IDs to Terraform outputs. Do not assume the outputs exist before an apply.

## Risks / production extensions

Subnet tier labels alone do not enforce network isolation. Add security groups, NACL decisions where justified, flow logs, routing reviews, tagging policies and workload-specific controls. For critical workloads design egress (per-AZ NAT, private endpoints, proxy) with resilience and cost in mind. For production use separate AWS accounts, scoped cross-account roles and secure central state. Pin an exact tested provider version via `.terraform.lock.hcl` after init. Review AZ selection: AZ names map differently across AWS accounts; AZ IDs are preferable for cross-account deterministic physical AZ alignment.

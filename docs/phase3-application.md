# Phase 3: Application Tier (EC2, ALB, SSM, CloudWatch)

## Safety and cost

`enable_application = false` for all environments. With it set to `true`, AWS starts charging for the public Application Load Balancer (hourly + LCU usage), EC2, and EBS. With `enable_ssm_endpoints = true` AWS adds three interface endpoint services in *two* AZs (six hourly endpoint attachments plus data processing). Alarms may incur charges. Check AWS Pricing Calculator in your region and use AWS Budgets. `enable_ssm_endpoints = false` + no NAT means the instance cannot use Session Manager and has no general outbound internet; the bundled AL2023 Python service runs without installing packages.

This is an **HTTP-only interview lab**, NOT production-ready. In production use ACM + HTTPS 443, redirect HTTP, WAF as applicable, durable application logs, controlled patching, more than one application instance and an incident response plan. `desired_capacity=1` is deliberately not highly available. IAM role is provisioned for Systems Manager, but Sessions won't connect without functional VPC endpoints or another egress path.

## Changes from Phase 2

New module: `modules/application/{versions.tf,variables.tf,main.tf,outputs.tf,user_data.sh.tftpl}`.
Every environment's `main.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars.example` adds opt-in application config, no changes to `modules/networking/` or backend files.

## Deploy ONLY dev after review

```bash
cd environments/dev
# Assumes Phase 2 S3 backend already initialized and accessible
cp terraform.tfvars.example terraform.tfvars  # only if you haven't already made this file
# Edit terraform.tfvars: enable_application=true
terraform fmt -recursive ../../
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -out=dev.phase3.tfplan
terraform show dev.phase3.tfplan
terraform apply dev.phase3.tfplan
terraform output -raw application_alb_dns
curl "http://$(terraform output -raw application_alb_dns)/health"
```

If you already have a `terraform.tfvars`, do NOT overwrite it: append `enable_application = true`. Ensure AWS credentials point to the intended account and confirm expected monthly costs. Keep staging/prod disabled; test their `terraform plan` without apply.

## Operational checks

- AWS EC2 > Target Groups: target health; ASG instance health.
- CloudWatch > Alarms: `${project}-${env}-healthy-hosts-low`. Optionally set `alarm_email` and confirm SNS opt-in.
- User data logs: `/var/log/cloud-init-output.log` (reachable via SSM only with endpoints/NAT).
- Launch template uses the Amazon Linux 2023 SSM public parameter for x86_64. Some organizations require an approved pinned AMI rather than a floating lookup.
- The app has a `/health` route on port 8080; SG only permits ALB -> app.
- SSM endpoints are optional; they must use private DNS and VPC DNS settings. Endpoint service availability varies by region. In regions that do not offer `ec2messages`, adjust the list; latest SSM Agents favor `ssmmessages`.
- Default AWS EC2 metrics are basic resolution, so the 60-second CloudWatch ALB alarm does not imply 60-second instance CPU monitoring.

## Rehearse questions

1. Why place EC2 in private subnets while the ALB is public?
2. Why are SSM endpoints necessary when there is no NAT?
3. Why doesn't a single ASG instance across two subnets provide AZ high availability?
4. How would you add TLS, logs, backups, patching, WAF, and automated rollback?
5. What ongoing costs remain even if no requests reach the application?

## Destroy application without deleting VPC

Set `enable_application = false`, run `terraform plan`, review deletions, then apply. This removes the application module while keeping the network. When all the infrastructure is no longer needed, use `terraform destroy` in dev. Do not delete the remote state bucket until you have safely destroyed every tracked environment and retained any necessary state backups.

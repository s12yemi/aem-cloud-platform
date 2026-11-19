# Remote state bootstrap (phase 2)

The initial VPC deployment uses *local* state for a simple first lab. Never commit it. Before collaborating, running CI applies, or treating staging/prod as deployable, migrate each environment to an encrypted, versioned S3 state bucket with native lockfiles.

1. Create a globally unique bucket using `scripts/create-state-bucket.sh aem-terraform-state-UNIQUE ca-central-1`.
2. Copy `environments/dev/backend.tf.example` to `environments/dev/backend.tf` (and repeat per environment).
3. Edit `backend.tf` to uncomment the backend block (`backend "s3" {}`) and create `backend.hcl` from `backend.hcl.example`, replacing the bucket name.
4. From the environment directory run `terraform init -migrate-state -backend-config=backend.hcl` and carefully review its prompt.
5. Validate successful migration with `terraform state list`, and securely remove local state and its backups **only after** confirming remote state is correct.

Each environment uses a distinct state key. For real organizations, prefer separate AWS accounts and roles per environment, with narrowly scoped S3 permissions and governance over the state bucket. Do not use root credentials. The bootstrap script does not set up IAM access policies for your team or CI; do that before collaboration.

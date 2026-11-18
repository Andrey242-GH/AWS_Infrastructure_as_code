# Terraform + AWS CLI setup and pushing the image to ECR

This project builds a PHP/Apache Docker image (`Dockerfile`). Terraform creates the
ECR repository, and a shell script builds and pushes the image (Terraform does not
build Docker images).

## Quick start (one command)

After installing the tools and configuring AWS credentials (sections 1 and 2):

```bash
./scripts/deploy.sh up          # create ECR repo, build and push image (:latest)
./scripts/deploy.sh up v1       # same, with tag v1
./scripts/deploy.sh destroy     # delete the images and the ECR repo
```

`deploy.sh` runs without confirmation prompts (`-auto-approve`) and sets
`force_delete=true` so the repo is removed even when it contains images.
Sections 3 to 5 below describe the same steps done manually.

## 1. Install the tools (Ubuntu/Debian, x86_64)

Quick way:

```bash
./scripts/install-tools.sh
```

Manual way:

```bash
# Terraform
sudo apt-get update && sudo apt-get install -y gnupg curl unzip lsb-release
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform

# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip && sudo ./aws/install
```

On ARM machines use `awscli-exe-linux-aarch64.zip`.

Verify:

```bash
terraform version
aws --version
docker --version
```

## 2. Configure AWS credentials

Create an IAM user (or use SSO) with ECR permissions (`ecr:*` on the repo is enough,
plus `ecr:GetAuthorizationToken`). Then:

```bash
aws configure          # access key, secret, default region
aws sts get-caller-identity   # confirm it works
```

In a Codespace you can instead export `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
and `AWS_DEFAULT_REGION`. Never commit credentials.

## 3. Create the ECR repository

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Defaults: region `us-east-1`, repository `my-php-app`. Override with:

```bash
terraform apply -var="aws_region=eu-west-1" -var="repository_name=other-name"
```

Note: `scripts/push-image.sh` tags the local image as `my-php-app`; the ECR name only
comes from Terraform outputs, so they may differ.

## 4. Build and push the image

From the project root:

```bash
./scripts/push-image.sh          # pushes :latest
./scripts/push-image.sh v1       # pushes :v1
```

The script reads the repo URL from Terraform outputs, logs Docker in to ECR, builds
the image, tags it and pushes it.

Check the result:

```bash
aws ecr describe-images --repository-name my-php-app --region us-east-1
```

## 5. Clean up

```bash
cd terraform
terraform destroy
```

Destroy fails if the repo holds images, unless you set `-var="force_delete=true"` and
apply first, or delete the images manually.

## Files

| Path | Purpose |
|---|---|
| `terraform/main.tf` | Provider, ECR repo, lifecycle policy (keeps last 10 images) |
| `terraform/variables.tf` | Region, repo name, etc. |
| `terraform/outputs.tf` | Repo URL, registry, region (used by the script) |
| `scripts/install-tools.sh` | Installs Terraform and AWS CLI |
| `scripts/deploy.sh` | One command: `up` (terraform + push) or `destroy` |
| `scripts/push-image.sh` | Docker login, build, tag, push |

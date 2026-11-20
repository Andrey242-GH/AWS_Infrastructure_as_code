# Create an ECR Repository and Push the Image

Terraform creates the ECR repository. A shell script builds the Docker image and pushes it (Terraform does not build images).

Prerequisites:

- Terraform and AWS CLI installed: [01-setup/01-install-terraform-and-aws-cli.md](../01-setup/01-install-terraform-and-aws-cli.md) (or run `./scripts/install-tools.sh`).
- AWS credentials configured: [01-setup/02-aws-credentials-in-codespaces.md](../01-setup/02-aws-credentials-in-codespaces.md). The IAM user needs ECR permissions, including `ecr:GetAuthorizationToken`.
- Docker installed: [04-containers/02-docker-install-and-first-lesson.md](../04-containers/02-docker-install-and-first-lesson.md).

## Quick start

```bash
./scripts/deploy.sh up          # create ECR repo, build and push image (:latest)
./scripts/deploy.sh up v1       # same, with tag v1
./scripts/deploy.sh destroy     # delete the images and the ECR repo
```

`deploy.sh` runs without confirmation prompts (`-auto-approve`) and sets `force_delete=true` so the repo is removed even when it contains images. The sections below do the same steps manually.

## 1. Create the repository

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

## 2. Build and push the image

From the project root:

```bash
./scripts/push-image.sh          # pushes :latest
./scripts/push-image.sh v1       # pushes :v1
```

The script reads the repository URL from the Terraform outputs, logs Docker in to ECR, builds the local image `py-automation:<tag>`, tags it with the ECR URL and pushes it. The local image name (`py-automation`) can differ from the ECR repository name, which comes from Terraform.

Check the result:

```bash
aws ecr describe-images --repository-name my-php-app --region us-east-1
```

The equivalent plain Docker commands are in the [cheatsheet](../04-containers/03-docker-commands-cheatsheet.md#7-push-to-a-registry).

## 3. Clean up

```bash
cd terraform
terraform destroy
```

Destroy fails if the repository holds images, unless you apply with `-var="force_delete=true"` first or delete the images manually.

## Files

| Path | Purpose |
|---|---|
| `terraform/main.tf` | Provider, ECR repo, lifecycle policy (keeps last 10 images) |
| `terraform/variables.tf` | Region, repo name, etc. |
| `terraform/outputs.tf` | Repo URL, registry, region (used by the script) |
| `scripts/install-tools.sh` | Installs Terraform and AWS CLI |
| `scripts/deploy.sh` | `up` (terraform + push) or `destroy` |
| `scripts/push-image.sh` | Docker login, build, tag, push |

# Study Report: Docker, Terraform and AWS

## 1. Summary

This project is my hands-on practice for containers and cloud infrastructure. I started with AWS networking using the AWS CLI and Terraform, then moved to Docker: building a PHP/Apache image, running containers, and publishing the image to AWS ECR (Elastic Container Registry) with Terraform and shell scripts. I also recorded an instruction video about ECS (Elastic Container Service).

All work lives in a GitHub repository, developed in GitHub Codespaces.

## 2. What I did

### 2.1 Environment and tooling
- Set up GitHub Codespaces and a GitHub repository (`Docs/05-github`, `Docs/01-setup`).
- Installed Terraform and AWS CLI and configured AWS credentials in Codespaces.
- Installed Kiro CLI as an AI assistant.

### 2.2 AWS networking
- Studied core networking concepts: VPC, subnets, route tables, internet gateway, NAT gateway and Elastic IP (`Docs/02-aws-fundamentals`).
- Built the same network twice: first with AWS CLI scripts, then with Terraform (VPC, subnets, NAT gateway, outputs, variables).
- Documented the Terraform workflow: `init`, `plan`, `apply`, `destroy` (`Docs/03-infrastructure-as-code`).

### 2.3 Docker
- Learned the difference between an image and a container.
- Wrote a `Dockerfile` based on `php:7.2-apache` and built it with `docker build`.
- Ran containers with port mapping (`-p 8080:80`), detached mode, `--rm`, and named containers.
- Mounted local files with a volume (`-v`) for development.
- Passed database settings with environment variables (`-e`).
- Inspected and cleaned up with `docker images`, `docker ps`, `docker logs`, `docker rm`, `docker rmi`.
- Added a PHP and MySQL setup with Docker Compose (see the git history).
- Wrote clear course notes in `Steps.md` and the `Docs/04-containers` folder.

### 2.4 Publishing the image to AWS ECR
- Terraform (`terraform/`) creates the ECR repository with image scanning and a lifecycle policy (keeps the last 10 images).
- `scripts/push-image.sh` logs in to ECR, builds, tags and pushes the image. This part is a script because Terraform does not build Docker images.
- `scripts/deploy.sh up` does everything in one command, and `scripts/deploy.sh destroy` removes the images and the repository.
- `scripts/install-tools.sh` installs Terraform and AWS CLI.
- `INSTALL_AND_DEPLOY.md` documents the full process.

### 2.5 ECS instruction video
- Recorded an instruction video explaining ECS. ECS is the AWS service that runs containers, so it is the natural next step after pushing an image to ECR.

## 3. Problems found and solved

| Problem | Cause | Fix |
|---|---|---|
| `Unable to find image 'rm:latest'` | Typo `-- rm` with a space: Docker read `rm` as the image name | Use `--rm` |
| Port error | `808@:80` typo and a missing `-p` | `-p 8080:80` |
| Options ignored | Options placed after the image name | Put all options before the image name |
| Old PHP tags missing | `php:7.x` is end-of-life | Use a maintained tag such as `php:8.2-apache` |
| ECR repo cannot be destroyed | Repo still contains images | `force_delete = true`, applied before destroy |
| Database not reachable | `127.0.0.1` inside a container is the container itself | Use the DB container name or `host.docker.internal` |

## 4. Concepts learned

- Image, container, registry, tag.
- Port mapping, volumes, environment variables.
- Infrastructure as code: declarative (Terraform) versus imperative (CLI scripts), state, plan before apply.
- Why some tasks need scripts next to Terraform (building and pushing images).
- Cost awareness: NAT gateways and Elastic IPs bill while they exist, so run `destroy` after practicing.

## 5. Advice and next steps

**For the project**
1. **Update the base image.** `php:7.2-apache` is end-of-life. Use `php:8.2-apache` or newer, and keep the README and Dockerfile consistent.
2. **Keep secrets out of git.** Use `.env` files (ignored by git) locally and AWS Secrets Manager or SSM Parameter Store in AWS. Rotate any password that was ever pasted in a terminal, chat or commit.
3. **Use image tags other than `latest`.** Tag with a version or commit hash so you can roll back. Consider `IMMUTABLE` tags in ECR.
4. **Store Terraform state remotely** (S3 bucket with locking) once more than one person or machine uses it. Local state is fine for learning.
5. **Always destroy practice resources** and check the AWS Billing page.
6. **Add a `.dockerignore`** (`.git`, `terraform/`, `Docs/`) to keep images small.
7. **Clean the repository.** There are notes in several places (`Steps.md`, `Docs/`, `INSTALL_AND_DEPLOY.md`). Link them from the README so a reader has one starting point.

**For the ECS video**
- Open with the problem: where does the container run after it is in ECR?
- Explain the pieces in this order: cluster, task definition, service, and the launch type (Fargate runs containers without managing servers, EC2 means you manage the servers).
- Show the connection to this project: the ECR image URL is what goes into the task definition.
- Cover networking from your earlier work: the service needs subnets, a security group, and either a public IP or a load balancer. This ties your VPC study to ECS.
- Cover the IAM task execution role, which lets ECS pull the image from ECR and write logs to CloudWatch. It is the most common cause of failed tasks.
- Do a live demo: deploy, open the public IP, check CloudWatch logs, then destroy everything.
- Mention cost: Fargate bills per running task, so stop or delete the service.
- Keep it short, with a one-slide architecture diagram: Developer, ECR, ECS (Fargate), VPC, user.

**Suggested next learning steps**
1. Add the ECS cluster, task definition, service and IAM role to Terraform so the whole path (VPC, ECR, ECS) is one `terraform apply`.
2. Use GitHub Actions to build and push the image on every commit.
3. Add an Application Load Balancer and CloudWatch alarms.
4. Practice Docker Compose with PHP and MySQL, then move the database to Amazon RDS.

## 6. Repository map

| Path | Purpose |
|---|---|
| `Dockerfile`, `index.php`, `index.html` | The application and its image |
| `Steps.md` | Docker course notes |
| `Docs/` | Setup, AWS networking, Terraform and container documentation |
| `terraform/` | ECR repository (Terraform) |
| `scripts/` | Install, push and deploy/destroy scripts |
| `INSTALL_AND_DEPLOY.md` | Install tools and publish the image to ECR |

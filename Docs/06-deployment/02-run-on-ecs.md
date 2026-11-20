# Deploying a Docker Image to ECR and Running It on ECS (Fargate or EC2)

This guide walks through the full path: build an image, push it to Amazon ECR, then run it on Amazon ECS using either Fargate or EC2. It uses the AWS CLI so each step is explicit. You can do the same things in the console.

## 0. Concepts

| Term | Meaning |
|---|---|
| **ECR** (Elastic Container Registry) | Private registry that stores your Docker images. |
| **ECS** (Elastic Container Service) | AWS container orchestrator. It decides where containers run and keeps them running. |
| **Task definition** | JSON blueprint for your container(s): image, CPU, memory, ports, env vars, logging, IAM roles. |
| **Task** | A running instance of a task definition. |
| **Service** | Keeps N tasks running, replaces failed ones, and connects to a load balancer. |
| **Cluster** | Logical group of tasks/services (and EC2 instances, if you use EC2). |
| **Fargate** | Serverless launch type. AWS manages the servers. You pay per vCPU/memory per second. |
| **EC2 launch type** | You run and manage EC2 instances that join the cluster. You pay for the instances. |

Flow:

```
Dockerfile -> docker build -> docker push -> ECR
                                              |
Task definition (references the ECR image) <--+
        |
   ECS Service -> Fargate  or  EC2 instances
        |
   (optional) Application Load Balancer -> users
```

### Fargate vs EC2

| | Fargate | EC2 |
|---|---|---|
| Server management | None | You patch and scale instances |
| Pricing | Per task resources used | Per instance, whether full or not |
| Best for | Most apps, getting started | Steady high utilization, GPUs, special instance types, cost tuning at scale |
| Network mode | `awsvpc` only | `awsvpc`, `bridge`, `host` |

For learning, start with Fargate.

## 1. Prerequisites

- An AWS account and an IAM user/role with permissions for ECR, ECS, IAM (pass role), EC2/VPC, CloudWatch Logs.
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), configured with `aws configure` (or SSO).
- Docker installed and running.
- A default VPC with public subnets (most accounts have one), or your own VPC.

Set variables used throughout (bash):

```bash
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export REPO_NAME=my-app
export CLUSTER_NAME=my-cluster
export SERVICE_NAME=my-app-service
export IMAGE_TAG=v1
```

## 2. Create a sample app and Dockerfile

Skip this if you already have an image.

`app.py`:
```python
from http.server import BaseHTTPRequestHandler, HTTPServer

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"Hello from ECS\n")

HTTPServer(("0.0.0.0", 8080), H).serve_forever()
```

`Dockerfile`:
```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY app.py .
EXPOSE 8080
CMD ["python", "app.py"]
```

Build and test locally:
```bash
docker build -t $REPO_NAME:$IMAGE_TAG .
docker run --rm -p 8080:8080 $REPO_NAME:$IMAGE_TAG
curl localhost:8080
```

> If you build on an Apple Silicon Mac, add `--platform linux/amd64` (or run Fargate with ARM64). Otherwise the task fails with `exec format error`.

## 3. Create the ECR repository and push the image

```bash
aws ecr create-repository \
  --repository-name $REPO_NAME \
  --image-scanning-configuration scanOnPush=true \
  --region $AWS_REGION
```

Authenticate Docker to ECR (token lasts 12 hours):
```bash
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
```

Tag and push:
```bash
export IMAGE_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:$IMAGE_TAG
docker tag $REPO_NAME:$IMAGE_TAG $IMAGE_URI
docker push $IMAGE_URI
```

Verify:
```bash
aws ecr describe-images --repository-name $REPO_NAME --region $AWS_REGION
```

Tips:
- Use unique tags (version or git SHA), not just `latest`, so deployments are reproducible and rollbacks are easy.
- Add a lifecycle policy to delete old images and control storage cost.

## 4. Create IAM roles

### Task execution role (required)
ECS uses this role to pull the image from ECR and write logs. It is not your app's role.

```bash
cat > ecs-trust.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "ecs-tasks.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role --role-name ecsTaskExecutionRole \
  --assume-role-policy-document file://ecs-trust.json

aws iam attach-role-policy --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```
(If `ecsTaskExecutionRole` already exists in your account, skip the create.)

### Task role (optional)
If your app calls AWS services (S3, DynamoDB), create a separate role with the same trust policy and only the permissions the app needs, then set it as `taskRoleArn` in the task definition.

## 5. Create a cluster and log group

```bash
aws ecs create-cluster --cluster-name $CLUSTER_NAME --region $AWS_REGION
aws logs create-log-group --log-group-name /ecs/$REPO_NAME --region $AWS_REGION
```

## 6. Networking

Find your default VPC and subnets:
```bash
export VPC_ID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text)
aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID \
  --query 'Subnets[*].[SubnetId,AvailabilityZone]' --output table
export SUBNET_1=subnet-aaaa    # replace
export SUBNET_2=subnet-bbbb    # replace
```

Create a security group that allows inbound traffic to the app port:
```bash
export SG_ID=$(aws ec2 create-security-group --group-name my-app-sg \
  --description "my-app" --vpc-id $VPC_ID --query GroupId --output text)

aws ec2 authorize-security-group-ingress --group-id $SG_ID \
  --protocol tcp --port 8080 --cidr 0.0.0.0/0
```
`0.0.0.0/0` is fine for a demo. In production, only allow the load balancer's security group.

---

# Option A: Run on Fargate

## A1. Task definition

`taskdef-fargate.json`:
```json
{
  "family": "my-app",
  "requiresCompatibilities": ["FARGATE"],
  "networkMode": "awsvpc",
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::ACCOUNT_ID:role/ecsTaskExecutionRole",
  "runtimePlatform": {
    "cpuArchitecture": "X86_64",
    "operatingSystemFamily": "LINUX"
  },
  "containerDefinitions": [
    {
      "name": "my-app",
      "image": "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/my-app:v1",
      "essential": true,
      "portMappings": [{"containerPort": 8080, "protocol": "tcp"}],
      "environment": [{"name": "APP_ENV", "value": "dev"}],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/my-app",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```
Replace `ACCOUNT_ID` and the region. Valid CPU/memory pairs are restricted (for example 256 CPU supports 512, 1024, 2048 MB). See the AWS docs for the table.

Register it:
```bash
aws ecs register-task-definition --cli-input-json file://taskdef-fargate.json
```

## A2. Create the service

```bash
aws ecs create-service \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --task-definition my-app \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_1,$SUBNET_2],securityGroups=[$SG_ID],assignPublicIp=ENABLED}"
```
`assignPublicIp=ENABLED` is needed in public subnets so the task can reach ECR. In private subnets, use a NAT gateway or VPC endpoints for ECR (api and dkr), S3 (gateway), and CloudWatch Logs.

## A3. Test

```bash
aws ecs wait services-stable --cluster $CLUSTER_NAME --services $SERVICE_NAME

TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME \
  --query 'taskArns[0]' --output text)

ENI=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN \
  --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" --output text)

PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI \
  --query 'NetworkInterfaces[0].Association.PublicIp' --output text)

curl http://$PUBLIC_IP:8080
```

---

# Option B: Run on EC2

You need EC2 instances registered to the cluster.

## B1. Instance role

Create an instance profile so the ECS agent can register the instance.

```bash
cat > ec2-trust.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role --role-name ecsInstanceRole \
  --assume-role-policy-document file://ec2-trust.json
aws iam attach-role-policy --role-name ecsInstanceRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role
aws iam create-instance-profile --instance-profile-name ecsInstanceRole
aws iam add-role-to-instance-profile \
  --instance-profile-name ecsInstanceRole --role-name ecsInstanceRole
```

## B2. Launch an ECS-optimized instance

Get the latest ECS-optimized Amazon Linux 2023 AMI:
```bash
AMI_ID=$(aws ssm get-parameter \
  --name /aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id \
  --query Parameter.Value --output text)
```

Launch it, telling the ECS agent which cluster to join via user data:
```bash
cat > userdata.sh <<EOF
#!/bin/bash
echo ECS_CLUSTER=$CLUSTER_NAME >> /etc/ecs/ecs.config
EOF

aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.small \
  --subnet-id $SUBNET_1 \
  --security-group-ids $SG_ID \
  --iam-instance-profile Name=ecsInstanceRole \
  --associate-public-ip-address \
  --user-data file://userdata.sh \
  --count 1
```

Confirm it registered (may take a minute or two):
```bash
aws ecs list-container-instances --cluster $CLUSTER_NAME
```

For real workloads, use an Auto Scaling group with a launch template and an ECS capacity provider instead of launching instances by hand. That lets ECS scale instances with demand.

## B3. Task definition

`taskdef-ec2.json`:
```json
{
  "family": "my-app-ec2",
  "requiresCompatibilities": ["EC2"],
  "networkMode": "bridge",
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::ACCOUNT_ID:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "my-app",
      "image": "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/my-app:v1",
      "essential": true,
      "portMappings": [{"containerPort": 8080, "hostPort": 8080, "protocol": "tcp"}],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/my-app",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```
Using `hostPort: 0` gives a dynamic host port, which allows several copies on one instance behind a load balancer. With a fixed hostPort, only one task per instance can run.

```bash
aws ecs register-task-definition --cli-input-json file://taskdef-ec2.json
```

## B4. Create the service

```bash
aws ecs create-service \
  --cluster $CLUSTER_NAME \
  --service-name my-app-ec2-service \
  --task-definition my-app-ec2 \
  --desired-count 1 \
  --launch-type EC2
```

## B5. Test

Find the instance's public IP and call it:
```bash
CI_ARN=$(aws ecs list-container-instances --cluster $CLUSTER_NAME \
  --query 'containerInstanceArns[0]' --output text)
EC2_ID=$(aws ecs describe-container-instances --cluster $CLUSTER_NAME \
  --container-instances $CI_ARN --query 'containerInstances[0].ec2InstanceId' --output text)
IP=$(aws ec2 describe-instances --instance-ids $EC2_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
curl http://$IP:8080
```

---

## 7. Deploying a new version

```bash
docker build -t $REPO_NAME:v2 .
docker tag $REPO_NAME:v2 $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:v2
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:v2
```
Edit the `image` tag in the task definition JSON, register it (creates a new revision), then update the service:
```bash
aws ecs register-task-definition --cli-input-json file://taskdef-fargate.json
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME \
  --task-definition my-app
```
ECS performs a rolling update: it starts new tasks, waits for them to be healthy, then stops old ones. To roll back, point the service at the previous revision (`my-app:1`).

## 8. Add a load balancer (production pattern)

1. Create an Application Load Balancer in public subnets with a listener on 80/443.
2. Create a target group: type `ip` for Fargate (or `instance` for EC2 bridge), port 8080, health check path such as `/`.
3. Add `--load-balancers targetGroupArn=...,containerName=my-app,containerPort=8080` to `create-service`.
4. Run tasks in private subnets. Allow inbound 8080 only from the ALB security group.

## 9. Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `CannotPullContainerError` | Task has no route to ECR (no public IP or NAT/VPC endpoints), wrong image URI, or the execution role lacks ECR permissions. |
| `exec format error` | Image architecture mismatch. Build for `linux/amd64`, or set `cpuArchitecture` to `ARM64`. |
| Task stops immediately | Check container logs in CloudWatch `/ecs/my-app` and the stopped reason: `aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks <arn>`. |
| Service stuck at 0 running | Check service events: `aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --query 'services[0].events[:5]'`. |
| Can't reach the app | Security group missing the port, wrong port mapping, or app binds to `127.0.0.1` instead of `0.0.0.0`. |
| EC2: no container instances | Wrong `ECS_CLUSTER` in user data, missing instance profile, or no internet route to the ECS endpoint. |
| EC2: task `RESOURCE:MEMORY/CPU` placement failure | Instance lacks free CPU/memory or the fixed hostPort is already in use. |
| Log group not found | Create `/ecs/my-app` first, or set `awslogs-create-group: "true"` and grant `logs:CreateLogGroup`. |

## 10. Clean up (to avoid charges)

```bash
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --desired-count 0
aws ecs delete-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --force
# EC2 option: terminate the instance(s) and delete my-app-ec2-service
aws ecs delete-cluster --cluster $CLUSTER_NAME
aws ecr delete-repository --repository-name $REPO_NAME --force
aws logs delete-log-group --log-group-name /ecs/$REPO_NAME
aws ec2 delete-security-group --group-id $SG_ID
```
Delete the security group after tasks and instances are gone, otherwise it is still in use.

## 11. Best practices

- Tag images with git SHAs or versions, and enable ECR scan on push.
- Use separate task execution and task roles, each with least privilege.
- Keep secrets in Secrets Manager or SSM Parameter Store and reference them with `secrets` in the container definition. Do not put them in `environment`.
- Run tasks in private subnets behind an ALB.
- Enable the service deployment circuit breaker for automatic rollback: `--deployment-configuration "deploymentCircuitBreaker={enable=true,rollback=true}"`.
- Define infrastructure as code (Terraform, CloudFormation, or CDK) once you understand the manual steps.
- Automate build, push, and deploy in CI/CD (for example GitHub Actions with `aws-actions/amazon-ecr-login` and `aws-actions/amazon-ecs-deploy-task-definition`, using OIDC instead of long-lived keys).

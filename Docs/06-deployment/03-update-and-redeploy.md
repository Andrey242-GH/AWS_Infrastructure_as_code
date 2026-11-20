# Heartbeat Feature and Redeploying the Updated Image

This guide covers two things:

1. What the heartbeat feature added to `main.py` and how to run it.
2. How to rebuild the image, push the new version to ECR, and make a running service use it.

## 1. What changed

The dashboard still shows the URL status table. Nothing was removed. A second table, **Heartbeat**, now sits below it.

Every 5 minutes (and once at startup), the app adds a new row with metadata about the container. Rows are never overwritten. Newest is shown first.

| Column | Meaning |
|---|---|
| `#` | Heartbeat counter, starting at 1 for each container start |
| Time | UTC time of the heartbeat |
| Uptime | Seconds since the container started |
| Host / AZ | Container hostname. On ECS it shows the availability zone instead |
| PID | Process ID |
| Python | Python version |
| Memory | Peak memory used by the process |
| URLs up | How many monitored URLs were up at that moment, for example `2/2` |

On ECS, the heartbeat JSON also includes `task_arn`, `availability_zone` and `launch_type`. These come from the ECS metadata endpoint (`ECS_CONTAINER_METADATA_URI_V4`), which ECS sets automatically. They appear in `/api/status`.

The first heartbeat after startup can show `0/0` for URLs, because the first URL checks have not finished yet. Later rows are correct.

### New settings

| Variable | Default | Meaning |
|---|---|---|
| `HEARTBEAT_INTERVAL` | `300` | Seconds between heartbeats (300 = 5 minutes) |
| `HEARTBEAT_MAX` | `288` | Rows kept in memory (288 rows is 24 hours at 5 minutes). The oldest row is dropped after that |
| `HEARTBEAT_FILE` | empty | If set, each heartbeat is also appended to this file as one JSON line |

### History is lost on restart by default

Rows are held in memory. When the container restarts or is replaced (including during a deploy), the table starts empty and `#` restarts at 1.

To keep history, set `HEARTBEAT_FILE` and mount a volume:

```bash
docker run --rm -p 8080:8080 \
  -e HEARTBEAT_FILE=/data/heartbeats.jsonl \
  -v "$PWD/data:/data" \
  py-automation
```
The file survives restarts, but the web page only shows rows from the current run. The file is the permanent record. The container user (`appuser`) must be able to write to the mounted folder. If it can't, the app logs a warning and keeps running.

On ECS, a file inside the container disappears with the task. For durable history on ECS you would need an EFS volume or to send the data to something like CloudWatch Logs or S3. The heartbeat is already written to the container logs, so with the `awslogs` driver every heartbeat ends up in CloudWatch.

## 2. Test locally

Build and run with a short interval so you can see rows appear quickly:

```bash
docker build -t py-automation .
docker run --rm -p 8080:8080 -e HEARTBEAT_INTERVAL=10 py-automation
```
Open `http://localhost:8080` (in Codespaces, use the Ports tab). A new heartbeat row appears every 10 seconds. Drop the `-e` to use the real 5-minute interval.

If you get `port is already allocated`, another container is using 8080. Check with `docker ps`, then either stop it (`docker stop <name>`) or map a different host port, such as `-p 8081:8080`.

Check the JSON:
```bash
curl -s localhost:8080/api/status
```

## 3. Push the new image to ECR

The scripts in `scripts/` already do this. Use a new version tag each time so you can roll back.

```bash
# Make sure AWS credentials work
aws sts get-caller-identity

# Build and push as v2
scripts/push-image.sh v2
```

What the script does:
1. Reads the ECR repository URL from Terraform output.
2. Logs Docker in to ECR (`aws ecr get-login-password`).
3. Builds the image from the repo root `Dockerfile`.
4. Tags it as `<repo-url>:v2`.
5. Pushes it.

If the repository does not exist yet, run `scripts/deploy.sh up v2` instead. It creates the repository with Terraform first and then pushes.

Verify the image arrived:
```bash
REPO=$(terraform -chdir=terraform output -raw repository_url | cut -d/ -f2-)
aws ecr describe-images --repository-name "$REPO" \
  --query 'sort_by(imageDetails,&imagePushedAt)[].[imageTags,imagePushedAt]' --output table
```

Notes:
- The repository is configured as `MUTABLE`, so pushing `latest` again overwrites it. Versioned tags like `v2` are safer.
- The repository keeps only the last 10 images (lifecycle policy). Older ones are deleted automatically.
- The repository is still named `my-php-app` in `terraform/variables.tf`. It works fine with the Python image. Renaming it would make Terraform delete and recreate the repository.

## 4. Make the running service use the new image

Pushing to ECR does not change what is running. ECS keeps running the old image until you tell it to deploy. This section applies once you have an ECS service (see [run-on-ecs](02-run-on-ecs.md) for creating one).

Set variables:
```bash
export AWS_REGION=us-east-1          # your region
export CLUSTER_NAME=my-cluster
export SERVICE_NAME=my-app-service
export TASK_FAMILY=my-app
export NEW_IMAGE=$(terraform -chdir=terraform output -raw repository_url):v2
```

### Option A: new version tag (recommended)

1. Get the current task definition and swap in the new image:
   ```bash
   aws ecs describe-task-definition --task-definition $TASK_FAMILY \
     --query taskDefinition > taskdef.json

   python3 - <<'EOF'
   import json, os
   t = json.load(open("taskdef.json"))
   t["containerDefinitions"][0]["image"] = os.environ["NEW_IMAGE"]
   # Remove fields that register-task-definition does not accept
   for k in ["taskDefinitionArn","revision","status","requiresAttributes",
             "compatibilities","registeredAt","registeredBy"]:
       t.pop(k, None)
   json.dump(t, open("taskdef-new.json", "w"), indent=2)
   EOF
   ```
2. Register the new revision and update the service:
   ```bash
   aws ecs register-task-definition --cli-input-json file://taskdef-new.json
   aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME \
     --task-definition $TASK_FAMILY
   ```
   Using the family name without a revision picks the latest revision.
3. Wait for it to finish:
   ```bash
   aws ecs wait services-stable --cluster $CLUSTER_NAME --services $SERVICE_NAME
   ```

ECS starts new tasks, waits for them to pass health checks, and then stops the old ones.

### Option B: you pushed over the same tag (`latest`)

The task definition does not change, so force a new deployment. ECS pulls the image again when it starts new tasks:
```bash
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --force-new-deployment
```

### Roll back

Point the service at the previous task definition revision:
```bash
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME \
  --task-definition $TASK_FAMILY:1      # replace 1 with the earlier revision
```

## 5. Verify the deployment

1. Check the service events and counts:
   ```bash
   aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME \
     --query 'services[0].[runningCount,desiredCount,deployments[].[status,taskDefinition]]'
   ```
2. Open the dashboard. The **Heartbeat** table should exist, and on ECS the host column shows an availability zone.
3. Check `/api/status`. Heartbeats should include `task_arn`.
4. Read the logs:
   ```bash
   aws logs tail /ecs/my-app --since 10m --follow
   ```
   You should see a line like `heartbeat #3 uptime=600s urls_up=2/2` every 5 minutes.

Because a deploy replaces the container, the heartbeat table restarts at `#1`. This is expected.

## 6. Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| Dashboard looks the same after deploy | Old tasks still running. Check `describe-services` deployments, or you pushed `latest` without `--force-new-deployment`. |
| Deployment stuck, tasks keep restarting | Health check path must be `/health` on port 8080. Check the stopped task reason and the logs. |
| `CannotPullContainerError` | Wrong image URI or tag, or the task has no route to ECR. |
| `exec format error` | Image built on an ARM machine but the task is `X86_64`. Build with `docker build --platform linux/amd64`. |
| No heartbeat file written | The mounted folder is not writable by `appuser`, or `HEARTBEAT_FILE` is unset. Check the container logs for a warning. |
| `no basic auth credentials` on push | ECR login expired (12 hours). Run `scripts/push-image.sh` again, which logs in each time. |
| Table is empty right after start | Normal for a few seconds. The first heartbeat is written at startup. |

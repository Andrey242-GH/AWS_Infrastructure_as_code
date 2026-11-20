# Docker Commands Cheatsheet

The commands you will use most, grouped by task. Examples use this project's image (`py-automation`, a Python app listening on port 8080). Replace names and tags with your own.

## 1. Build an image

```bash
# Build from the Dockerfile in the current directory and tag it
docker build -t py-automation:v1 .

# Build with a different Dockerfile
docker build -f Dockerfile.dev -t py-automation:dev .

# Rebuild from scratch, ignoring the layer cache
docker build --no-cache -t py-automation:v1 .

# Build for a specific CPU architecture (e.g. for ECS Fargate on x86_64 from an ARM Mac)
docker build --platform linux/amd64 -t py-automation:v1 .
```

Image names have the form `[registry/]name:tag`. If you omit the tag, Docker uses `latest`.

`.dockerignore` keeps files such as `.git` and `terraform/` out of the build context, which makes builds faster and images smaller.

## Dockerfile basics

The project's `Dockerfile`:

```dockerfile
FROM python:3.12-slim          # base image
ENV PYTHONUNBUFFERED=1         # set an environment variable
WORKDIR /app                   # working directory for the next steps
RUN useradd --create-home appuser   # run a command at build time
USER appuser                   # run as a non-root user from here on
COPY --chown=appuser main.py . # copy files from the build context
EXPOSE 8080                    # documents the port; does not publish it
CMD ["python", "main.py"]      # default command when the container starts
```

`RUN` executes at build time, `CMD` at run time. `EXPOSE` is documentation only. You still need `-p` to publish a port.

## 2. Update an image

Images are immutable. To "update" one, change the code or Dockerfile, build again with a new tag, and run the new image.

```bash
# 1. Edit main.py or the Dockerfile
# 2. Build a new version
docker build -t py-automation:v2 .

# 3. Stop and remove the old container, then start one from the new image
docker stop web && docker rm web
docker run -d --name web -p 8080:8080 py-automation:v2
```

Notes:

- Use a new tag per release (`v1`, `v2`, a git SHA). Re-using `latest` makes rollbacks hard.
- Docker caches layers. Put rarely changing steps (installing dependencies) before frequently changing ones (`COPY main.py`) in the Dockerfile so rebuilds stay fast.
- To refresh a base image or an image from a registry: `docker pull python:3.12-slim`, then rebuild with `--no-cache` if needed.
- Roll back by running the previous tag: `docker run -d --name web -p 8080:8080 py-automation:v1`.

## 3. Run containers

```bash
# Run in the background, name it, publish host port 8080 to container port 8080
docker run -d --name web -p 8080:8080 py-automation:v1

# Run in the foreground and delete the container when it exits
docker run --rm -p 8080:8080 py-automation:v1

# Pass environment variables
docker run -d --name web -p 8080:8080 \
  -e URLS=https://example.com,https://www.python.org \
  -e INTERVAL=60 \
  py-automation:v1

# Mount the current folder into the container (bind mount, useful in development)
docker run --rm -v "$PWD":/app -p 8080:8080 py-automation:v1

# Restart automatically after a crash or reboot
docker run -d --restart unless-stopped --name web -p 8080:8080 py-automation:v1

# Interactive shell in a new container
docker run -it --rm python:3.12-slim bash
```

Port syntax is `-p HOST:CONTAINER`. Flags go before the image name. Anything after the image name is passed to the container as its command.

## 4. Inspect and debug

```bash
docker ps                    # running containers
docker ps -a                 # all containers, including stopped ones
docker logs web              # output of the container
docker logs -f --tail 100 web   # follow the last 100 lines
docker exec -it web bash     # shell in a running container (use sh if bash is missing)
docker inspect web           # full JSON: IP, mounts, env, exit code
docker stats                 # live CPU and memory use
docker top web               # processes inside the container
docker cp web:/app/main.py .  # copy a file out of a container
```

If a container exits immediately, run `docker logs <name>` and check `docker inspect -f '{{.State.ExitCode}}' <name>`.

## 5. Start, stop, remove

```bash
docker stop web          # graceful stop (SIGTERM, then SIGKILL after 10 s)
docker start web         # start a stopped container
docker restart web
docker rm web            # remove a stopped container
docker rm -f web         # stop and remove in one step
```

## 6. Manage images

```bash
docker images                          # list local images
docker pull nginx:1.27                 # download an image
docker tag py-automation:v1 py-automation:latest   # add another tag
docker rmi py-automation:v1            # remove an image
docker history py-automation:v1        # show layers and their sizes
docker save -o app.tar py-automation:v1    # export to a file
docker load -i app.tar                 # import from a file
```

## 7. Push to a registry

Docker Hub:

```bash
docker login
docker tag py-automation:v1 YOUR_USER/py-automation:v1
docker push YOUR_USER/py-automation:v1
```

Amazon ECR (what `scripts/push-image.sh` automates):

```bash
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

docker tag py-automation:v1 ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/REPO:v1
docker push ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/REPO:v1
```

## 8. Volumes and networks

```bash
# Volumes keep data after a container is removed
docker volume create data
docker run -d -v data:/data py-automation:v1
docker volume ls
docker volume rm data

# Networks let containers reach each other by name
docker network create appnet
docker run -d --name db --network appnet postgres:16
docker run -d --name web --network appnet -p 8080:8080 py-automation:v1
# "web" can now reach the database at host "db"
```

## 9. Docker Compose

Compose runs several containers from one `docker-compose.yaml`.

```bash
docker compose up -d            # create and start everything in the background
docker compose up -d --build    # rebuild images first (use this after changing code)
docker compose ps
docker compose logs -f web
docker compose exec web bash
docker compose down             # stop and remove containers and networks
docker compose down -v          # also remove volumes (deletes data)
```

## 10. Clean up

```bash
docker container prune          # remove all stopped containers
docker image prune              # remove dangling (untagged) images
docker image prune -a           # remove all images not used by a container
docker volume prune             # remove unused volumes (deletes data)
docker system df                # see how much space Docker uses
docker system prune             # stopped containers, unused networks, dangling images, build cache
```

The `prune` commands ask for confirmation. Check `docker system df` first, and be careful with `volume prune` and `-a`, because they delete data and images you may want later.

## 11. Common problems

| Symptom | Cause and fix |
|---|---|
| `port is already allocated` | Another process or container uses that host port. Change the left side of `-p`, or run `docker ps` and stop the other container. |
| `container name "/web" is already in use` | Run `docker rm -f web`, or pick another name. |
| Page does not load on `localhost:8080` | Check the mapping in `docker ps`, and make sure the app listens on `0.0.0.0` inside the container, not `127.0.0.1`. In Codespaces, open the forwarded port. |
| Code change has no effect | The container still uses the old image. Rebuild and recreate the container (section 2). |
| `Cannot connect to the Docker daemon` | Start Docker (`sudo service docker start`) or add your user to the `docker` group and log in again. |
| `no matching manifest for linux/arm64` | The image has no build for your CPU. Use `--platform linux/amd64`. |
| `-- rm` fails | Flags have no space after the dashes: `--rm`. |

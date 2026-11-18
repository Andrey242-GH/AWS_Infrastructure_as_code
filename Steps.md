# Docker Notes: PHP + Apache

## 1. The Dockerfile

A Dockerfile is the recipe used to build an image. Create a file named `Dockerfile` (no extension) in the project root:

```dockerfile
FROM php:7.2-apache
COPY index.php /var/www/html/
```

| Instruction | Meaning |
|---|---|
| `FROM` | Base image to start from (PHP with Apache already installed) |
| `COPY` | Copy a file from your machine into the image. `/var/www/html/` is the folder Apache serves |

> `php:7.2` is end-of-life. Prefer a maintained version, e.g. `php:8.3-apache`.

## 2. Build the image

```bash
docker build -t my-php-app .
```

- `-t my-php-app`: name (tag) given to the image
- `.`: build context, the current folder (where the Dockerfile is)

Add a version with `docker build -t my-php-app:v1 .` (the default tag is `latest`).

List images:

```bash
docker images
```

## 3. Run a container

An image is the template. A container is a running copy of it.

```bash
docker run -p 8080:80 --rm my-php-app
```

- `-p 8080:80`: map port 8080 on your machine to port 80 in the container (`HOST:CONTAINER`)
- `--rm`: delete the container automatically when it stops

Open <http://localhost:8080>. Ctrl+C stops it. In a Codespace, use the **Ports** tab and open the forwarded port 8080.

Run in the background (detached) with a name:

```bash
docker run -d --name myRunningApp -p 8080:80 my-php-app
```

- `-d`: detached, gives your terminal back
- `--name`: a name you choose, so you don't need the container ID

## 4. Manage containers

```bash
docker ps                          # running containers
docker ps -a                       # all containers, including stopped ones
docker stop myRunningApp           # stop (use the name or the container ID)
docker start myRunningApp          # start a stopped container again
docker rm myRunningApp             # remove a stopped container
docker logs -f myRunningApp        # show output, -f follows live
docker exec -it myRunningApp bash  # open a shell inside the container
```

## 5. Development mode: mount your files (volume)

Instead of rebuilding after every change, mount the current folder into the container. Edits show up on refresh.

```bash
docker run --rm -v "${PWD}":/var/www/html -p 8080:80 php:7.3-apache
```

- `-v HOST_PATH:CONTAINER_PATH`: `${PWD}` is the current directory

Common typos to avoid:

- `-- rm` (with a space): Docker treats `rm` as the image name. Use `--rm`.
- `808@:80`: must be `8080:80`.
- All options (`-p`, `-v`, `-e`, `--rm`) go **before** the image name. The image name comes last, unless you pass a command to run inside it.

## 6. Environment variables

Pass settings such as database details into the container with `-e`:

```bash
docker run --rm -p 8080:80 \
  -e DB_HOST='db' -e DB_USER='user' -e DB_PASS='secret' \
  my-php-app
```

In PHP, read them with `getenv('DB_HOST')`.

For many variables, keep them in a `.env` file and use `docker run --env-file .env ...`. Never commit passwords to git. Add `.env` to `.gitignore`.

> `127.0.0.1` inside a container means the container itself, not your machine. Use the database container's name or `host.docker.internal` instead.

## 7. Clean up

```bash
docker rmi my-php-app      # delete an image (add -f to force)
docker image prune         # remove unused (dangling) images
docker container prune     # remove all stopped containers
docker system prune        # remove all unused data (asks to confirm)
```

## 8. Quick reference

| Task | Command |
|---|---|
| Build | `docker build -t NAME .` |
| Run | `docker run -p HOST:CONTAINER --rm NAME` |
| List | `docker images` / `docker ps -a` |
| Stop | `docker stop NAME` |
| Delete | `docker rm NAME` / `docker rmi NAME` |
| Debug | `docker logs NAME` / `docker exec -it NAME bash` |

## 9. Push the image to AWS (ECR)

Terraform creates the ECR repository and a script builds and pushes the image. Full instructions are in [INSTALL_AND_DEPLOY.md](INSTALL_AND_DEPLOY.md).

```bash
./scripts/deploy.sh up         # create repo + build + push
./scripts/deploy.sh destroy    # delete the images and the repo
```

What the push does under the hood:

```bash
aws ecr get-login-password --region REGION | docker login --username AWS --password-stdin REGISTRY
docker tag my-php-app:latest REPO_URL:latest
docker push REPO_URL:latest
```

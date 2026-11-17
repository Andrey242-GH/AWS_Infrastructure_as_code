# Docker: Setup, Core Concepts, and Practical Usage

## Table of Contents

1. [Installing Docker](#1-installing-docker)
2. [Verifying Your Installation](#2-verifying-your-installation)
3. [Core Docker Concepts Recap](#3-core-docker-concepts-recap)
4. [Essential Docker Commands](#4-essential-docker-commands)
5. [Running Your First Container](#5-running-your-first-container)
6. [Volumes and Bind Mounts](#6-volumes-and-bind-mounts)
7. [Course Lesson 1: Run Apache and Inspect Docker](#7-course-lesson-1-run-apache-and-inspect-docker)
8. [Writing a Dockerfile](#8-writing-a-dockerfile)
9. [Docker Compose Basics](#9-docker-compose-basics)
10. [Common Errors and Fixes](#10-common-errors-and-fixes)

---

## 1. Installing Docker

### On Ubuntu / Debian (including GitHub Codespaces)

```bash
# Update package index
sudo apt-get update

# Install required packages
sudo apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

### On macOS

Download and install **Docker Desktop** from [https://www.docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop).
Docker Desktop includes the Docker Engine, CLI, and Docker Compose.

### On Windows

Download and install **Docker Desktop** from the same link above.
Enable WSL 2 integration if prompted (recommended).

### Run Docker Without sudo (Linux only)

```bash
# Add your user to the docker group
sudo usermod -aG docker $USER

# Apply the change (or log out and back in)
newgrp docker
```

---

## 2. Verifying Your Installation

```bash
# Check Docker is installed and running
docker --version

# Run the official hello-world test container
docker run hello-world

# Check Docker system info
docker info
```

A successful `hello-world` run prints a message confirming Docker can pull images and run containers.

---

## 3. Core Docker Concepts Recap

| Term | What it means |
|------|--------------|
| **Image** | A read-only blueprint for a container (like a class) |
| **Container** | A running instance of an image (like an object) |
| **Dockerfile** | A script of instructions used to build an image |
| **Registry** | A storage service for images (Docker Hub is the default) |
| **Volume** | Persistent storage that survives container removal |
| **Bind Mount** | Maps a host directory directly into a container |
| **Port Mapping** | Connects a port on your host to a port inside a container |

---

## 4. Essential Docker Commands

### Image Commands

```bash
# Pull an image from Docker Hub
docker pull nginx

# List all locally stored images
docker images

# Remove an image
docker rmi nginx

# Search Docker Hub for an image
docker search php
```

### Container Commands

```bash
# Run a container (pulls image if not local)
docker run nginx

# Run in detached (background) mode
docker run -d nginx

# Run with a custom name
docker run -d --name my-web nginx

# Run and remove the container automatically when it stops
docker run --rm nginx

# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# Stop a running container
docker stop my-web

# Start a stopped container
docker start my-web

# Remove a stopped container
docker rm my-web

# View logs from a container
docker logs my-web

# Follow logs in real time
docker logs -f my-web

# Open a shell inside a running container
docker exec -it my-web bash
```

### System Cleanup

```bash
# Remove all stopped containers
docker container prune

# Remove unused images
docker image prune

# Remove everything unused (containers, images, networks, build cache)
docker system prune
```

---

## 5. Running Your First Container

### Interactive Ubuntu shell

```bash
docker run -it ubuntu bash
```

- `-i` keeps STDIN open (interactive)
- `-t` allocates a terminal (TTY)

You are now inside the container. Type `exit` to leave.

### A simple web server

```bash
# Run nginx on port 8080 of your host
docker run -d -p 8080:80 --name my-nginx nginx
```

Then open `http://localhost:8080` in your browser.

**How port mapping works:**

```
-p <host-port>:<container-port>
-p 8080:80   →   your machine's port 8080 → container's port 80
```

---

## 6. Volumes and Bind Mounts

Containers are **ephemeral** — data written inside them is lost when the container is removed.
Use volumes or bind mounts to persist data or share files with the host.

### Bind Mount (host folder → container folder)

```bash
# Maps the current working directory into the container
docker run -v ${PWD}:/var/www/html nginx
```

| Part | Meaning |
|------|---------|
| `${PWD}` | Current directory on your host machine |
| `/var/www/html` | Path inside the container where the files appear |

### Named Volume (Docker-managed storage)

```bash
# Create a volume
docker volume create mydata

# Use it when running a container
docker run -v mydata:/var/lib/mysql mysql

# List volumes
docker volume ls

# Remove a volume
docker volume rm mydata
```

Use bind mounts when you want to edit files on your host and see changes live in the container.
Use named volumes for database data or anything you want Docker to manage.

---

## 7. Course Lesson 1: Run Apache and Inspect Docker

The first lesson in this course is a practical introduction to running a container and inspecting what Docker creates. You run a PHP and Apache image to serve the files in your current directory, then check the downloaded image and the running container.

### 1. Check the images already on your machine

```bash
docker images
```

This lists local images. If `php:8.2-apache` is not listed yet, Docker will download it from Docker Hub the first time you run the command below.

### 2. Run the PHP and Apache container

From the directory containing your `index.php`, run:
```bash
docker run --rm -v ${PWD}:/var/www/html -p 8080:80 php:8.2-apache
```

This starts Apache with PHP inside a container. The bind mount makes the current directory available to Apache, so it can serve your `index.php`. You do not need to install Apache or PHP directly on your machine.

### 3. Check the running container

Leave the server command running, open a second terminal, and run:

```bash
docker ps
```

`docker ps` lists active containers. To see the image each container uses and the port mapping, you can use:

```bash
docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
```

You should see a `php:8.2-apache` container with host port `8080` mapped to container port `80`. The container is the running instance; the image is the packaged environment it was started from.

### 4. Open the page and stop the container

Open `http://localhost:8080` in your browser (or use your Codespace's forwarded port). Apache serves the files from the mounted directory.

Press `Ctrl+C` in the terminal running Docker to stop the container. Because this command uses `--rm`, Docker removes the container when it stops. The image remains available locally:

```bash
docker images
docker ps
```

The image should still be listed, while the stopped container should no longer appear in `docker ps`.

### What this lesson demonstrates

- `docker run` creates and starts a container from an image.
- Docker downloads the image automatically if it is not already local.
- `docker images` lists local images; `docker ps` lists running containers.
- `-v ${PWD}:/var/www/html` shares the current directory with Apache in the container.
- `-p 8080:80` forwards traffic from host port 8080 to Apache's port 80.
- `--rm` removes the container after it stops, but does not remove the image.

### How the command works

---

### Why `docker run`?

`docker run` tells Docker to create a new container and start it immediately. If the image does not exist on your machine yet, Docker automatically pulls it from Docker Hub before starting. This is the core command you use whenever you want to launch a containerised application.

---

### Why `--rm`?

Without `--rm`, every time you run a container Docker keeps a stopped copy of it on disk after it exits. Over time these pile up and waste space. The `--rm` flag tells Docker to automatically delete the container the moment it stops, keeping your environment clean.

This is especially useful during development when you are starting and stopping the container frequently. You are not losing anything important by deleting it because all your actual PHP files live on your host machine, not inside the container.

---

### Why `-v ${PWD}:/var/www/html`?

This is a **bind mount**. It connects a folder on your host machine to a folder inside the container.

- `${PWD}` is a shell variable that expands to your current working directory — the folder you are in when you run the command.
- `/var/www/html` is where Apache inside the container looks for files to serve.

Without this flag, the container would have no access to your PHP files at all. Apache would serve an empty document root. By mounting your local folder into that path, you are telling Apache: "serve the files from my project directory."

The practical benefit is that any file you edit on your host is immediately visible to the container — no rebuild, no restart, no copy step needed. Save a change in `index.php` and refresh the browser to see it.

---

### Why `-p 8080:80`?

Containers run in an isolated network. By default, nothing on your host machine can reach a port inside a container. The `-p` flag punches a hole between the two.

The format is `-p <host-port>:<container-port>`.

- Port `80` is the port Apache listens on inside the container.
- Port `8080` is the port you use on your own machine to reach it.

This means when you open `http://localhost:8080` in your browser, your machine forwards that request to port 80 inside the container, where Apache is waiting.

Port 8080 is chosen on the host side because port 80 often requires root privileges on Linux, and it may already be in use by another service. 8080 is a common convention for local development to avoid both problems.

---

### Why `php:8.2-apache`?

This is the image name. It tells Docker which pre-built environment to use.

- `php` is the official PHP image on Docker Hub, maintained by the PHP project.
- `8.2` is a supported PHP version tag that works reliably with current Docker Hub images.
- `apache` is a variant tag meaning this image comes with Apache already installed and configured alongside PHP. Without the `apache` variant, the base `php` image only includes the PHP CLI with no web server.

By combining PHP and Apache into one image, this single command replaces what would otherwise require installing and configuring both tools manually.

---

### Putting it all together

```
docker run   --rm              -v ${PWD}:/var/www/html     -p 8080:80       php:8.2-apache
   │            │                       │                        │                 │
Launch a    Delete it          Serve your local            Expose it on        Use PHP 8.2
container   when done          PHP files via Apache         port 8080          with Apache
```

---

### Trying it out with your own PHP page

1. Create an `index.php` file in your current directory:

```php
<?php
echo "<h1>Hello from PHP in Docker!</h1>";
phpinfo();
?>
```

2. Run the command:

```bash
docker run --rm -v ${PWD}:/var/www/html -p 8080:80 php:8.2-apache
```

3. Open `http://localhost:8080` in your browser. You will see your PHP page rendered by Apache running inside the container.

4. Edit `index.php` and refresh the browser — the change appears immediately because of the bind mount.

5. Press `Ctrl+C` to stop the container. The `--rm` flag cleans it up automatically.

---

### Running it in the background

If you want to keep your terminal free while the server runs:

```bash
docker run -d --rm -v ${PWD}:/var/www/html -p 8080:80 --name php-dev php:8.2-apache
```

The `-d` flag detaches the container so it runs silently in the background. Give it a name with `--name` so you can refer to it easily:

```bash
# Check it is running
docker ps

# View its logs
docker logs php-dev

# Stop it (--rm handles cleanup automatically)
docker stop php-dev
```

---

## 8. Writing a Dockerfile

A Dockerfile lets you build a custom image instead of relying purely on run-time flags.

### Example: PHP Apache with a custom config

```dockerfile
# Start from the official PHP Apache image
FROM php:8.2-apache

# Copy your app files into the image at build time
COPY . /var/www/html/

# Optional: install PHP extensions
RUN docker-php-ext-install mysqli pdo pdo_mysql

# Expose the port Apache listens on
EXPOSE 80
```

### Build and run the image

```bash
# Build an image tagged as my-php-app
docker build -t my-php-app .

# Run a container from your custom image
docker run --rm -p 8080:80 my-php-app
```

The `.` at the end of `docker build` tells Docker to use the current directory as the build context (where it looks for the Dockerfile and any files you COPY).

---

## 9. Docker Compose Basics

Docker Compose lets you define and run multi-container applications using a YAML file, which is easier to manage than long `docker run` commands.

### Example `docker-compose.yml` for PHP + MySQL

```yaml
version: "3.8"

services:
  web:
    image: php:8.2-apache
    ports:
      - "8080:80"
    volumes:
      - .:/var/www/html

  db:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: rootpass
      MYSQL_DATABASE: myapp
      MYSQL_USER: appuser
      MYSQL_PASSWORD: apppass
    volumes:
      - db_data:/var/lib/mysql

volumes:
  db_data:
```

### Compose commands

```bash
# Start all services (pulls images if needed)
docker compose up

# Start in detached mode
docker compose up -d

# Stop all services
docker compose down

# Stop and remove volumes too
docker compose down -v

# View logs
docker compose logs

# Follow logs
docker compose logs -f web
```

---

## 10. Common Errors and Fixes

### `-- rm` vs `--rm` (your error)

```bash
# WRONG — space between -- and rm breaks the flag
docker run -- rm -v ${PWD}:/var/www/html -p 8080:80 php:8.2-apache

# CORRECT — no space
docker run --rm -v ${PWD}:/var/www/html -p 8080:80 php:8.2-apache
```

The space causes Docker to interpret `rm` as the name of the image, so it tries to pull an image called `rm`, which does not exist.

### Port already in use

```
Error: bind: address already in use
```

Another process is using port 8080. Either stop that process or use a different host port:

```bash
docker run --rm -v ${PWD}:/var/www/html -p 9090:80 php:8.2-apache
```
### Permission denied on bind mount

```bash
# Fix by granting permissions on the host directory
chmod -R 755 .
```

### Cannot connect to the Docker daemon

```bash
# Start Docker (Linux)
sudo systemctl start docker

# Or add yourself to the docker group and re-login
sudo usermod -aG docker $USER
newgrp docker
```

### Image not found / pull access denied

The image name or tag is wrong. Check it on [https://hub.docker.com](https://hub.docker.com):

```bash
# Search from the CLI
docker search php
```

### Container exits immediately

The main process inside the container stopped. Check logs:

```bash
docker logs <container-id-or-name>
```

---

## Quick Reference Card

```
docker pull <image>              # Download an image
docker run <image>               # Run a container
docker run -d <image>            # Run in background
docker run -it <image> bash      # Interactive shell
docker run -p 8080:80 <image>    # Map ports
docker run -v ${PWD}:/path <image>  # Bind mount
docker ps                        # List running containers
docker ps -a                     # List all containers
docker stop <name>               # Stop a container
docker rm <name>                 # Remove a container
docker images                    # List images
docker rmi <image>               # Remove an image
docker logs <name>               # View container logs
docker exec -it <name> bash      # Shell into container
docker system prune              # Clean up unused resources
```

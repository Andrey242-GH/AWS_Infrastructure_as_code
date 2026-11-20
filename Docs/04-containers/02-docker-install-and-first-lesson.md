# Docker: Install and First Lesson

Install Docker, check it works, and run the first course lesson (PHP and Apache). For the full command list, see the [commands cheatsheet](03-docker-commands-cheatsheet.md). For the image vs container idea, see the [container introduction](01-container-intro.md).

## Table of Contents

1. [Installing Docker](#1-installing-docker)
2. [Verifying Your Installation](#2-verifying-your-installation)
3. [Core Docker Concepts Recap](#3-core-docker-concepts-recap)
4. [Course Lesson 1: Run Apache and Inspect Docker](#4-course-lesson-1-run-apache-and-inspect-docker)

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

## 4. Course Lesson 1: Run Apache and Inspect Docker

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

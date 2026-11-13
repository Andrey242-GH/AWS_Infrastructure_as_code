The key difference between a virtual machine (VM) and Docker is the level of virtualization. A VM simulates an entire computer, including a full guest operating system, while Docker virtualizes at the operating system level. Containers share the host machine's kernel and package only the application and its dependencies.

This means a VM behaves like a complete machine, while a container behaves more like a lightweight, isolated process with its own filesystem and runtime environment.

## VM vs Docker: Core Differences

| Comparison Dimension | Virtual Machine (VM) | Docker Container |
| --- | --- | --- |
| Virtualization level | Hardware-level: simulates full hardware, including a complete guest OS and kernel | Operating system-level: shares the host kernel and includes only the app and runtime dependencies |
| Resource overhead | High: each VM needs its own full OS, which consumes significant CPU, memory, and disk space | Low: no separate OS is required, so more containers can run on the same hardware |
| Startup time | Slow: must boot a full OS, often taking minutes | Fast: usually starts in seconds or even milliseconds |
| Isolation | Strong isolation: complete separation from the host and other VMs | Lightweight isolation: process-level isolation using namespaces and cgroups |
| OS compatibility | Flexible: can run different operating systems, such as Windows on Linux | Limited: must match the host kernel family, so Linux containers require a Linux kernel |

## When to Choose Which?

Choose a VM when:
- You need strong isolation between workloads
- You must run different operating systems on the same machine
- You have strict security or compliance requirements
- You are working with untrusted or highly sensitive applications

Choose Docker when:
- You want fast startup and easy scaling
- You are building microservices or many short-lived services
- You need consistency across development, testing, and production environments
- You want to reduce "works on my machine" problems
- You are using CI/CD pipelines for rapid deployment

Docker is not a replacement for VMs in every scenario. It is best when you want lightweight, portable application environments without the overhead of running a full guest OS.

## Images vs Containers in Docker

A useful mental model is this: a container is like a running process, while an image is like the packaged application that makes that process possible.

| Dimension | Docker Image | Docker Container |
| --- | --- | --- |
| What it is | A read-only template that contains the filesystem, app code, libraries, and metadata | A running or stopped instance created from an image |
| State | Immutable: once built, it does not change | Mutable: it has a writable layer that can change at runtime |
| Analogy | A class in object-oriented programming, or a recipe/cookie cutter | An object/instance, or the actual cookie |
| Storage | A stack of read-only layers shared across images and containers | The image layers plus one thin writable layer per container |
| Lifecycle | Built, pulled, pushed, and tagged | Created, started, stopped, and removed |
| Persistence | Stored in a registry or locally until deleted | Ephemeral by default; data in the writable layer is lost when the container is removed unless you use volumes |
| Relationship | One image can be used to run many containers | Each container is created from exactly one image |

### Key ideas to remember

- An image is made of immutable layers. Each instruction in a Dockerfile creates a new layer.
- Layers are cached and shared, which is one reason Docker is so efficient.
- A container is an image plus a writable layer. When you run an image, Docker adds a thin copy-on-write layer on top.
- Any file changes made inside a container happen only in that writable layer, not in the original image.
- Containers are disposable, but images are the versioned deliverable you build, test, and ship.

This is why the usual practice is to treat containers as temporary, replaceable units and images as the actual artifacts of your application.

### Important note about changes

If you modify a file inside a container, that change does not automatically update the image. To make the change permanent, you must update the Dockerfile and rebuild the image.

The correct way to keep data alive across container restarts is to use Docker volumes or bind mounts.

## Quick Mental Model

Dockerfile --build--> Image --run--> Container(s)
(source)           (immutable)        (running instances)

Think of it like this:

- Dockerfile = the source definition
- Image = the packaged application artifact
- Container = the running instance of that artifact

You can launch the same image many times, and each container will run independently with its own temporary filesystem and runtime state.

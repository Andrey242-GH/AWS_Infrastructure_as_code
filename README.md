# Docker Learning Lab

This repository documents a Docker course I am taking and the hands-on lessons I complete along the way.

The goal is to learn the core Docker workflow:
- create a container image
- run containers
- inspect container behavior
- connect services together
- manage images and containers cleanly

This is not focused on AWS infrastructure deployment. It is focused on learning Docker fundamentals and how containers work in real projects.

## Course notes

The notes explain the concepts covered in the course and record the commands I use to practice them. Lesson 1 focuses on running a PHP and Apache container, then inspecting the Docker image and active container.

Start with the [container introduction](Docs/04-containers/01-container-intro.md), then follow [Docker setup and usage](Docs/04-containers/02-docker-setup-and-usage.md) for the first practical lesson.

## Documentation structure

```text
Docs/
  01-setup/
    01-install-terraform-and-aws-cli.md
    02-aws-credentials-in-codespaces.md
    03-github-codespaces-setup.md
  02-aws-fundamentals/
    01-networking-concepts-explained.md
  03-infrastructure-as-code/
    01-terraform-workflow.md
  04-containers/
    01-container-intro.md
    02-docker-setup-and-usage.md
  05-github/
    01-github-repository-setup.md
```

## Lesson 1: Run Apache and inspect Docker

The first practical lesson uses the `php:7.3-apache` image to serve the course directory through Apache. It introduces the difference between an image and a running container, and practices checking local images with `docker images` and active containers with `docker ps`.

See the full steps and command explanations in [Lesson 1: Run Apache and Inspect Docker](Docs/04-containers/02-docker-setup-and-usage.md#7-course-lesson-1-run-apache-and-inspect-docker).

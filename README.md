# Docker Learning Lab

Notes and hands-on lessons from a Docker course. The project is a small Python app (`main.py`, a URL status dashboard) that is built into an image, pushed to Amazon ECR with Terraform, and run on ECS.

## Where to start

| I want to | Read |
|---|---|
| Understand images vs containers | [Container introduction](Docs/04-containers/01-container-intro.md) |
| Install Docker and run the first lesson | [Install and first lesson](Docs/04-containers/02-docker-install-and-first-lesson.md) |
| Look up a command (build, update, run, push, clean up) | [Docker commands cheatsheet](Docs/04-containers/03-docker-commands-cheatsheet.md) |
| Push the image to AWS | [Push to ECR](Docs/06-deployment/01-push-to-ecr.md) |

## Documentation structure

```text
Docs/
  01-setup/                  Terraform, AWS CLI, credentials, Codespaces
  02-aws-fundamentals/       Networking concepts
  03-infrastructure-as-code/ Terraform workflow
  04-containers/             Concepts, install, lesson 1, commands cheatsheet
  05-github/                 Saving the project to GitHub
  06-deployment/             Push to ECR, run on ECS, update and redeploy
```

## Quick run

```bash
docker build -t py-automation:v1 .
docker run --rm -p 8080:8080 py-automation:v1
```

Then open `http://localhost:8080`.

# Saving a GitHub Codespaces Project to GitHub

This guide covers two common scenarios:

1. Creating a **new GitHub repository directly from GitHub Codespaces** and saving your project there.
2. Saving your Codespaces project to an **existing empty GitHub repository**.

---

## Option 1: Create a New Repository from Codespaces

If you have a project in GitHub Codespaces but no repository for it yet, you can create one directly from the terminal using the GitHub CLI.

### Step 1: Open the Terminal

In Codespaces, open the terminal and verify that the GitHub CLI is available:

```bash
gh --version
gh auth status
```

### Step 2: Initialize Git

Go to your project directory if necessary:

```bash
cd your-project
```

Initialize the project as a Git repository:

```bash
git init
```

### Step 3: Add Your Project Files

Check your files, then stage and commit them:

```bash
git status
git add .
git commit -m "Initial commit"
git branch -M main
```

### Step 4: Create the GitHub Repository

Create a new private GitHub repository:

```bash
gh repo create my-project --private --source=. --remote=origin
```

Replace `my-project` with the name you want. To make it public instead:

```bash
gh repo create my-project --public --source=. --remote=origin
```

### Step 5: Push the Project

```bash
git push -u origin main
```

Confirm the remote connection:

```bash
git remote -v
```

---

## Option 2: Push to an Existing Empty Repository

If you already created an empty repository on GitHub and want to push your Codespaces project to it:

### Step 1: Initialize Git

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
```

### Step 2: Connect the Existing Repository

```bash
git remote add origin https://github.com/yourusername/your-repo.git
git remote -v
```

You should see:

```text
origin  https://github.com/yourusername/your-repo.git (fetch)
origin  https://github.com/yourusername/your-repo.git (push)
```

### Step 3: Push the Project

```bash
git push -u origin main
```

---

## Day-to-Day Workflow

Once the repository is set up, you do not need to repeat the initialization steps. The normal workflow for any change is:

```bash
git status
git add .
git commit -m "Describe what changed"
git push
```

For more specific staging (recommended):

```bash
git status
git add path/to/changed-file
git diff --staged
git commit -m "Describe what changed"
git push
```

---

## Important: Use a `.gitignore`

Before running `git add .`, make sure your project has a `.gitignore` that excludes files that must not be committed — especially AWS credentials and Terraform state.

A minimal `.gitignore` for this project:

```text
.env
*.pem
*.key
.env.*
terraform.tfstate
terraform.tfstate.backup
tfplan
.terraform/
```

Always review `git status` before committing to confirm nothing sensitive is staged.

---

## Quick Reference

### New repository from Codespaces

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
gh repo create my-project --private --source=. --remote=origin
git push -u origin main
```

### Existing empty repository

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/yourusername/my-project.git
git push -u origin main
```

### Future changes

```bash
git status
git add path/to/file
git commit -m "Describe your changes"
git push
```

---

## Useful Git Commands

| Command | What it does |
|---|---|
| `git status` | Show changed and staged files |
| `git diff` | Show unstaged changes |
| `git diff --staged` | Show staged changes |
| `git log --oneline` | Show recent commits |
| `git branch` | List branches |
| `git remote -v` | Show configured remotes |
| `git pull` | Pull latest changes from GitHub |
| `git push` | Push committed changes to GitHub |

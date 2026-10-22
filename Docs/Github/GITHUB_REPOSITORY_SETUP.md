# Saving a GitHub Codespaces Project to GitHub

This guide covers two common scenarios:

1. Creating a **new GitHub repository directly from GitHub Codespaces** and saving your project there.
2. Saving your Codespaces project to an **existing empty GitHub repository**.

---

# Option 1: Create a New GitHub Repository from Codespaces

If you have a project in GitHub Codespaces but do not have a GitHub repository for it yet, you can create one directly from the Codespaces terminal using the GitHub CLI.

## Step 1: Open the Terminal

In Codespaces, open the terminal:

**Terminal → New Terminal**

Verify that the GitHub CLI is available:

```bash
gh --version
```

You can also verify that you are authenticated:

```bash
gh auth status
```

---

## Step 2: Initialize Git

Go to your project directory if necessary:

```bash
cd your-project
```

Initialize the project as a Git repository:

```bash
git init
```

---

## Step 3: Add Your Project Files

Check your files:

```bash
git status
```

Add all project files:

```bash
git add .
```

Create the first commit:

```bash
git commit -m "Initial commit"
```

Rename the branch to `main`:

```bash
git branch -M main
```

---

## Step 4: Create the GitHub Repository

Create a new GitHub repository directly from Codespaces:

```bash
gh repo create my-project --private --source=. --remote=origin
```

Replace:

```text
my-project
```

with the name you want for your repository.

For example:

```bash
gh repo create aws-vpc-project --private --source=. --remote=origin
```

If you want the repository to be public instead:

```bash
gh repo create aws-vpc-project --public --source=. --remote=origin
```

---

## Step 5: Push the Project

Push your project to the newly created repository:

```bash
git push -u origin main
```

Your project is now stored in GitHub.

You can confirm the connection with:

```bash
git remote -v
```

---

# Option 2: The GitHub Repository Already Exists and Is Empty

Suppose you already created an empty repository on GitHub and now want to save your Codespaces project there.

For example:

```text
https://github.com/yourusername/aws-vpc-project.git
```

## Step 1: Initialize Git

From your project directory:

```bash
git init
```

---

## Step 2: Add Your Files

```bash
git add .
```

Commit them:

```bash
git commit -m "Initial commit"
```

Make sure your branch is called `main`:

```bash
git branch -M main
```

---

## Step 3: Connect the Existing GitHub Repository

Add the empty GitHub repository as your remote:

```bash
git remote add origin https://github.com/yourusername/aws-vpc-project.git
```

Verify it:

```bash
git remote -v
```

You should see something similar to:

```text
origin  https://github.com/yourusername/aws-vpc-project.git (fetch)
origin  https://github.com/yourusername/aws-vpc-project.git (push)
```

---

## Step 4: Push the Project

Push your local project:

```bash
git push -u origin main
```

The project that was in Codespaces will now appear inside the GitHub repository.

---

# After the Initial Setup

Once the repository has been configured, you do **not** have to repeat the initialization or remote configuration.

When you modify your project, the normal workflow is:

## 1. Check what changed

```bash
git status
```

## 2. Add the changes

```bash
git add .
```

## 3. Commit the changes

```bash
git commit -m "Describe what changed"
```

For example:

```bash
git commit -m "Add VPC creation script"
```

## 4. Push the changes

```bash
git push
```

So your normal workflow becomes:

```bash
git status
git add .
git commit -m "Update project"
git push
```

---

# Quick Reference

## New repository created from Codespaces

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main

gh repo create my-project --private --source=. --remote=origin

git push -u origin main
```

## Existing empty GitHub repository

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main

git remote add origin https://github.com/yourusername/my-project.git

git push -u origin main
```

## Future changes

```bash
git status
git add .
git commit -m "Describe your changes"
git push
```

---

# Important: Use a `.gitignore`

Before running:

```bash
git add .
```

check whether your project contains files that should **not** be uploaded to GitHub.

For example, if you are working with AWS CLI scripts, do not commit AWS credentials, access keys, secret keys, `.env` files, or other secrets.

A basic `.gitignore` could contain:

```text
.env
*.pem
*.key
.env.*
```

Then you can safely run:

```bash
git add .
git status
```

Always review `git status` before committing.

---

# Useful Git Commands

Check repository status:

```bash
git status
```

See configured GitHub repository:

```bash
git remote -v
```

See commits:

```bash
git log --oneline
```

See branches:

```bash
git branch
```

See changed files:

```bash
git diff
```

Push changes:

```bash
git push
```

Pull changes from GitHub:

```bash
git pull
```
# Kiro CLI Setup for GitHub Codespaces

This guide explains how to install, authenticate, and use Kiro CLI inside a GitHub Codespace. It also covers the recommended Git workflow for creating a branch, reviewing Kiro's changes, committing them, and opening a pull request.

> **Note:** GitHub Codespaces runs in a remote Linux environment. The normal Kiro browser login may fail because the Codespace cannot open a browser directly. If that happens, use device-flow authentication as described below.

---

## Prerequisites

Before starting, confirm that:

- You have opened the correct GitHub repository in a Codespace.
- Your GitHub account has access to the repository.
- You have permission to create and push branches.
- The Codespace has internet access.

Check the basic tools:

```bash
curl --version
git --version
gh --version
```

---

## 1. Verify the Repository and GitHub Account

Confirm that the terminal is inside the expected repository:

```bash
pwd
git status
git remote -v
```

Check which GitHub account is authenticated:

```bash
gh auth status
gh api user --jq .login
```

The returned username must be the GitHub profile that has collaborator access to the repository.

---

## 2. Install Kiro CLI

Run the official Kiro CLI installer from the Codespace terminal:

```bash
curl -fsSL https://cli.kiro.dev/install | bash
```

The installer places the Kiro CLI executable in:

```text
~/.local/bin
```

---

## 3. Add Kiro CLI to the PATH

Add the installation directory to the current terminal session:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Make the setting persistent for future Bash sessions:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

If the Codespace uses Zsh:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Check the current shell if you are unsure:

```bash
echo "$SHELL"
```

---

## 4. Verify the Installation

```bash
which kiro-cli
kiro-cli --version
```

If the command is still not found, inspect the installation directory:

```bash
ls -la "$HOME/.local/bin"
source ~/.bashrc
```

---

## 5. Authenticate Kiro CLI

First try the normal login command:

```bash
kiro-cli login
```

In GitHub Codespaces, this may produce the following error because the remote environment cannot open a graphical browser:

```text
Failed to open browser for authentication.
Please try again with: kiro-cli login --use-device-flow
```

This does not mean the Kiro installation failed — it only means the Codespace could not open the authentication page automatically.

### Recommended login method for Codespaces

```bash
kiro-cli login --use-device-flow
```

Then complete these steps:

1. Wait for Kiro CLI to display an authentication URL and device code.
2. Copy the URL from the terminal.
3. Open the URL in the browser on your local computer.
4. Enter the device code if the page requests it.
5. Sign in and approve the authorization request.
6. Return to the Codespace terminal and wait for Kiro CLI to confirm authentication.

Do not share the device code, access tokens, or any credentials in commits, issues, or screenshots.

---

## 6. Prepare a Git Branch

Before letting Kiro modify files, start from an updated `main` branch and create a dedicated working branch:

```bash
git switch main
git pull --ff-only origin main
git switch -c your-branch-name
```

Verify the active branch:

```bash
git branch --show-current
```

Do not work directly on `main` unless the repository owner explicitly requires it.

---

## 7. Start Kiro CLI

Make sure you are in the repository root, then start Kiro:

```bash
kiro-cli chat
```

Kiro uses the current directory as project context, so start it from the repository you want it to inspect or modify.

Example requests:

```text
Explain the architecture of this repository.
```

```text
Review the Terraform files and identify any issues. Do not make changes yet.
```

```text
Create a plan for adding X before editing any files.
```

```text
Implement the approved change and summarize every modified file.
```

For infrastructure-as-code repositories, ask Kiro to plan before acting and review every proposed change before approving it.

---

## 8. Review All Changes

After Kiro modifies files, inspect the working tree:

```bash
git status
git diff
```

For AWS and infrastructure repositories, pay special attention to:

- Terraform state files (`terraform.tfstate`, `terraform.tfstate.backup`)
- `.env` files or any file containing AWS access keys or secrets
- Private key files
- Account IDs or ARNs
- Unexpected region, IAM, networking, or security group changes

Never commit AWS credentials, GitHub tokens, Kiro credentials, or any other secrets.

---

## 9. Stage and Commit the Changes

Stage only the specific files you reviewed:

```bash
git add path/to/changed-file
git diff --staged
git commit -m "Describe the change"
git log --oneline -5
```

---

## 10. Push the Branch

Push the branch and set its upstream tracking:

```bash
git push -u origin your-branch-name
```

After the first push, subsequent commits on the same branch can be pushed with:

```bash
git push
```

---

## 11. Create a Pull Request

```bash
gh pr create
```

Use `main` as the base branch. Include in the pull request description:

- A summary of the change
- The reason for the change
- Files or infrastructure components affected
- Any validation or testing performed
- Known risks or follow-up work

---

## Troubleshooting

### Kiro cannot open the browser

```bash
kiro-cli login --use-device-flow
```

Open the URL manually in your local browser and complete the authorization.

### `kiro-cli: command not found`

```bash
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
which kiro-cli
```

### Git push is denied

```bash
gh auth status
gh api user --jq .login
git remote -v
```

Confirm that the authenticated profile is a collaborator, the invitation was accepted, and the account has write permission.

### Kiro is missing after a Codespace rebuild

A Codespace can be rebuilt or recreated, so manually installed tools may not persist. Run the installation again if that happens.

---

## Quick Setup Reference

```bash
# Verify GitHub and repository context
gh api user --jq .login
git remote -v

# Install Kiro CLI
curl -fsSL https://cli.kiro.dev/install | bash

# Add Kiro to PATH
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify the installation
which kiro-cli
kiro-cli --version

# Authenticate (recommended method for Codespaces)
kiro-cli login --use-device-flow

# Create a working branch
git switch main
git pull --ff-only origin main
git switch -c your-branch-name

# Start Kiro
kiro-cli chat
```

After reviewing Kiro's changes:

```bash
git status
git diff
git add path/to/changed-file
git diff --staged
git commit -m "Describe the change"
git push -u origin your-branch-name
gh pr create
```

---

## Official Documentation

- Kiro CLI documentation: https://kiro.dev/docs/cli/
- Kiro CLI setup and first run: https://kiro.dev/docs/cli/setup/

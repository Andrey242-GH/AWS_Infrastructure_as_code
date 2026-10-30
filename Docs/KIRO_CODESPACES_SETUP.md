# Kiro CLI Setup for GitHub Codespaces

This guide explains the complete process for installing, authenticating, and using **Kiro CLI** inside a GitHub Codespace. It also covers the recommended Git workflow for creating a branch, reviewing Kiro's changes, committing them, pushing the branch, and opening a pull request.

> **Important:** GitHub Codespaces runs in a remote Linux environment. The normal Kiro browser login may fail because the Codespace cannot open a browser directly. If that happens, use device-flow authentication as described below.

## Prerequisites

Before starting, confirm that:

- You have opened the correct GitHub repository in a Codespace.
- Your GitHub account has access to the repository.
- You have permission to create and push branches.
- The Codespace has internet access.
- `curl`, Git, and GitHub CLI are available.

Check the basic tools:

```bash
curl --version
git --version
gh --version
```

## 1. Verify the Repository and GitHub Account

Confirm that the terminal is inside the expected repository:

```bash
pwd
git status
```

Check the repository remote:

```bash
git remote -v
```

The `origin` fetch and push URLs should point to the repository where you intend to create the branch.

Check which GitHub account is authenticated:

```bash
gh auth status
gh api user --jq .login
```

The returned username must be the GitHub profile that has collaborator access to the repository.

## 2. Install Kiro CLI

Run the official Kiro CLI installer from the Codespace terminal:

```bash
curl -fsSL https://cli.kiro.dev/install | bash
```

The installer normally places the Kiro CLI executable in a user-level binary directory such as:

```text
~/.local/bin
```

## 3. Add Kiro CLI to the PATH

If the installation completes but `kiro-cli` is not recognized, add the installation directory to the current terminal session:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Make the setting persistent for future Bash terminal sessions:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

If the Codespace uses Zsh instead of Bash, use:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Check the current shell if you are unsure:

```bash
echo "$SHELL"
```

## 4. Verify the Installation

Confirm that the executable is available:

```bash
which kiro-cli
kiro-cli --version
```

A successful installation should display the location of `kiro-cli` and its installed version.

If the command is still not found, inspect the installation directory:

```bash
ls -la "$HOME/.local/bin"
```

Then reload the shell configuration:

```bash
source ~/.bashrc
```

## 5. Authenticate Kiro CLI

You can first try the normal login command:

```bash
kiro-cli login
```

However, this may produce an error in GitHub Codespaces because the remote environment cannot open a graphical browser:

```text
Failed to open browser for authentication.
Please try again with: kiro-cli login --use-device-flow
error: No such file or directory (os error 2)
```

This does not mean the Kiro installation failed. It only means the Codespace could not open the authentication page automatically.

### Recommended login method for Codespaces

Use device-flow authentication:

```bash
kiro-cli login --use-device-flow
```

Then complete these steps:

1. Wait for Kiro CLI to display an authentication URL and, when applicable, a device code.
2. Copy the URL from the Codespace terminal.
3. Open the URL in the regular browser on your computer.
4. Enter the displayed device code if the page requests it.
5. Sign in with the account you want to use for Kiro.
6. Approve the authorization request.
7. Return to the Codespace terminal.
8. Wait for Kiro CLI to confirm that authentication succeeded.

Do not share the device code, access tokens, API keys, or other credentials in GitHub issues, commits, chat messages, or screenshots.

## 6. Prepare the Git Branch

Before allowing Kiro to modify files, start with an updated `main` branch:

```bash
git switch main
git pull --ff-only origin main
```

Create a dedicated working branch. Replace `healthprime-changes` with the appropriate branch name if needed:

```bash
git switch -c healthprime-changes
```

Verify the active branch:

```bash
git branch --show-current
git status
```

The expected branch should be:

```text
healthprime-changes
```

Do not make repository changes directly on `main` unless the repository owner explicitly requires that workflow.

## 7. Start Kiro CLI

Make sure you are in the repository root, then start Kiro:

```bash
kiro-cli
```

Depending on the installed version, you can also start the terminal chat interface with:

```bash
kiro-cli chat
```

Kiro uses the current directory as project context, so start it from the repository you want it to inspect or modify.

Example requests you can give Kiro:

```text
Explain the architecture of this repository.
```

```text
Review the Terraform files and identify configuration issues. Do not make changes yet.
```

```text
Create a plan for the requested infrastructure change before editing files.
```

```text
Implement the approved change and summarize every modified file.
```

For infrastructure-as-code repositories, ask Kiro to plan first and review every proposed command before approving it.

## 8. Review All Changes

After Kiro modifies files, exit or pause the Kiro session and inspect the working tree:

```bash
git status
git diff
```

Review changes before staging them. For AWS and infrastructure repositories, pay special attention to:

- Terraform state files such as `terraform.tfstate`
- `.env` files
- AWS access keys or secret keys
- Private keys
- Account IDs that should not be committed
- Generated plan files
- Local configuration files
- Unexpected provider, region, IAM, networking, or security-group changes

Check which ignored-file rules are active:

```bash
git status --ignored
```

Never commit AWS credentials, GitHub tokens, Kiro credentials, device codes, API keys, or other secrets.

## 9. Stage and Commit the Changes

Whenever possible, stage only the specific files you reviewed:

```bash
git add path/to/changed-file
```

If you intentionally want to stage all reviewed changes:

```bash
git add .
```

Review what is staged:

```bash
git status
git diff --staged
```

Create a descriptive commit:

```bash
git commit -m "Update AWS infrastructure configuration"
```

Confirm the commit:

```bash
git log --oneline -5
```

## 10. Push the Branch to GitHub

Push the branch for the first time and set its upstream tracking branch:

```bash
git push -u origin healthprime-changes
```

After the first successful push, later commits on the same branch can be pushed with:

```bash
git push
```

Verify branch tracking:

```bash
git branch -vv
```

You should see the local branch tracking `origin/healthprime-changes`.

## 11. Create a Pull Request

Create a pull request from the Codespace:

```bash
gh pr create
```

Use:

- **Base branch:** `main`
- **Compare branch:** `healthprime-changes`

Before submitting the pull request, include:

- A clear summary of the change
- The reason for the change
- The files or infrastructure components affected
- Validation or testing performed
- Any known risks or follow-up work

## 12. Continue Working on the Same Branch

For additional changes on the same branch:

```bash
git status
git diff
git add path/to/changed-file
git commit -m "Describe the additional change"
git push
```

## Troubleshooting

### Kiro cannot open the browser

Error:

```text
Failed to open browser for authentication.
```

Solution:

```bash
kiro-cli login --use-device-flow
```

Open the URL manually in your local browser and complete the authorization.

### `kiro-cli: command not found`

Temporarily add Kiro to the current PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then persist and reload it:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Verify:

```bash
which kiro-cli
kiro-cli --version
```

### Git push is denied

Check the authenticated GitHub profile:

```bash
gh auth status
gh api user --jq .login
```

Check the repository remote:

```bash
git remote -v
```

Confirm that:

- The authenticated profile is the collaborator account.
- The collaborator invitation was accepted.
- `origin` points to the intended repository.
- The account has write permission.
- Repository branch protection does not prevent the operation.

Do not create a fork automatically unless the repository workflow requires one.

### Kiro was installed, but a new Codespace cannot find it

A Codespace can be rebuilt or deleted, so manually installed tools may not persist in a newly created environment. Run the installation again, or later automate it through the repository's development-container configuration if the team wants every Codespace to include Kiro CLI.

## Quick Setup Reference

Run the following commands in order:

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

# Authenticate using the recommended Codespaces method
kiro-cli login --use-device-flow

# Update main and create a working branch
git switch main
git pull --ff-only origin main
git switch -c healthprime-changes

# Start Kiro
kiro-cli
```

After reviewing Kiro's changes:

```bash
git status
git diff
git add path/to/changed-file
git diff --staged
git commit -m "Update AWS infrastructure configuration"
git push -u origin healthprime-changes
gh pr create
```

## Official Documentation

- Kiro CLI documentation: https://kiro.dev/docs/cli/
- Kiro CLI setup and first run: https://kiro.dev/docs/cli/setup/

---

**Recommended filename:** `KIRO_CODESPACES_SETUP.md`

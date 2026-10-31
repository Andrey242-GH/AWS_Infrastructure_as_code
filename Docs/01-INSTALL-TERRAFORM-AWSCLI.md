# Install Terraform and AWS CLI

This guide covers installing both tools on the Ubuntu environment used by GitHub Codespaces.

---

## Install Terraform

HashiCorp provides an official APT repository for installing Terraform on Ubuntu and Debian systems.

Update the package list and install the required tools:

```bash
sudo apt-get update
sudo apt-get install -y gnupg software-properties-common wget
```

Add HashiCorp's signing key:

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
```

Add the HashiCorp APT repository:

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com \
  $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
```

Update the package list again, then install Terraform:

```bash
sudo apt-get update
sudo apt-get install -y terraform
```

---

## Install the AWS CLI

AWS recommends using its official installer to install AWS CLI v2 on Linux:

```bash
curl -fsSL 'https://awscli.amazonaws.com/v2/install.sh' | bash
```

The installer places the AWS CLI binary under `~/.local/bin`. Add it to your PATH for the current session:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

To make this persistent across terminal sessions:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

---

## Verify the Installations

Confirm that both tools are installed and on the PATH:

```bash
terraform --version
aws --version
```

Expected output will look similar to:

```text
Terraform v1.x.x
on linux_amd64

aws-cli/2.x.x Python/3.x.x Linux/x86_64
```

---

## Next Steps

- Configure AWS credentials: [02-AWS-CREDENTIALS-CODESPACES.md](02-AWS-CREDENTIALS-CODESPACES.md)
- Learn the AWS CLI and Terraform workflows: [03-TERRAFORM-WORKFLOW.md](03-TERRAFORM-WORKFLOW.md)

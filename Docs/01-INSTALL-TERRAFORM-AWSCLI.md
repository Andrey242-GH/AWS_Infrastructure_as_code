# Install Terraform

HashiCorp provides an official APT repository for installing Terraform on Ubuntu and Debian systems.

In your Codespaces terminal, update the package list and install the required tools:

```bash
sudo apt-get update
sudo apt-get install -y gnupg software-properties-common wget
```

Add HashiCorp’s signing key:

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
```

Add the HashiCorp APT repository:

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
```

Update the package list again, then install Terraform:

```bash
sudo apt-get update
sudo apt-get install -y terraform
```

# Install the AWS CLI

AWS recommends using its official installer to install AWS CLI v2 on Linux. Run the following command in your Codespaces terminal:

```bash
curl -fsSL 'https://awscli.amazonaws.com/v2/install.sh' | bash
```

To make the AWS CLI available in your current shell, add its installation directory to your `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

# Verify the installations

Confirm that Terraform and the AWS CLI are installed:

```bash
terraform --version
aws --version
```
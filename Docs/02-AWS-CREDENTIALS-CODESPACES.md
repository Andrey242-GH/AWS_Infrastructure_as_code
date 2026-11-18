# Secure AWS Credentials in GitHub Codespaces

This guide explains how to securely provide AWS credentials to AWS CLI and Terraform using GitHub Codespaces secrets.

AWS credentials should never be committed to the repository.

---

# 1. Required AWS Secrets

Create the following GitHub Codespaces secrets:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_DEFAULT_REGION
```

For example:

```text
AWS_DEFAULT_REGION=us-east-1
```

---

# 2. Open GitHub Codespaces Settings

In GitHub:

1. Click your profile picture.
2. Select **Settings**.
3. Select **Codespaces**.
4. Find **Codespaces secrets**.
5. Click **New secret**.

---

# 3. Create `AWS_ACCESS_KEY_ID`

Create a secret named:

```text
AWS_ACCESS_KEY_ID
```

Enter the AWS access key as the secret value.

Under **Repository access**, give access only to the repository that needs the credential.

For example:

```text
Andrey242-GH/EC2_Heartbeat_AWS_Infrastructure
```

Save the secret.

---

# 4. Create `AWS_SECRET_ACCESS_KEY`

Create another secret named:

```text
AWS_SECRET_ACCESS_KEY
```

Enter the AWS secret access key as the value.

Give it access to the same repository:

```text
Andrey242-GH/EC2_Heartbeat_AWS_Infrastructure
```

Save the secret.

---

# 5. Configure the AWS region

Create another Codespaces secret:

```text
AWS_DEFAULT_REGION
```

For example:

```text
us-east-1
```

Give the secret access to the same repository.

---

# 6. Restart the Codespace

If the Codespace was already running when the secret was created or modified:

1. Save the secret changes.
2. Stop the Codespace.
3. Start the Codespace again.

Opening another terminal is not the same as restarting the Codespace.

---

# 7. Verify That the Secrets Are Available

Do not print the actual AWS secret values.

Instead, check whether the variables exist:

```bash
if [ -n "${AWS_ACCESS_KEY_ID:-}" ]; then
    echo "AWS_ACCESS_KEY_ID configured"
else
    echo "AWS_ACCESS_KEY_ID missing"
fi

if [ -n "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    echo "AWS_SECRET_ACCESS_KEY configured"
else
    echo "AWS_SECRET_ACCESS_KEY missing"
fi
```

Expected output:

```text
AWS_ACCESS_KEY_ID configured
AWS_SECRET_ACCESS_KEY configured
```

Check the region:

```bash
echo "${AWS_DEFAULT_REGION:-AWS_DEFAULT_REGION is not configured}"
```

---

# 8. Verify AWS Authentication

Run:

```bash
aws sts get-caller-identity
```

If authentication is working correctly, AWS will return information about the AWS account and IAM identity being used.

---

# 9. Do Not Store Credentials in Terraform

Do not configure the AWS provider like this:

```hcl
provider "aws" {
  access_key = "YOUR_ACCESS_KEY"
  secret_key = "YOUR_SECRET_KEY"
}
```

The Terraform AWS provider should use the credentials provided by the environment instead.

For example:

```hcl
provider "aws" {
  region = var.aws_region
}
```

---

# 10. Do Not Commit AWS Credentials

Never commit AWS credentials to files such as:

```text
main.tf
providers.tf
variables.tf
terraform.tfvars
.env
README.md
*.sh
```

---

# Authentication Flow

The authentication flow for this project is:

```text
GitHub Codespaces Secrets
        |
        v
Codespace Environment Variables
        |
        +--> AWS_ACCESS_KEY_ID
        |
        +--> AWS_SECRET_ACCESS_KEY
        |
        +--> AWS_DEFAULT_REGION
                |
                v
        AWS CLI / Terraform
                |
                v
                AWS
```

This keeps AWS credentials outside the Terraform source code and Git repository.

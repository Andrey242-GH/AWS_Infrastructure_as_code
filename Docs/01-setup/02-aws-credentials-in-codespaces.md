# Secure AWS Credentials in GitHub Codespaces

This guide explains how to securely provide AWS credentials to the AWS CLI and Terraform using GitHub Codespaces secrets.

AWS credentials must never be committed to the repository.

---

## 1. Required AWS Secrets

Create the following three GitHub Codespaces secrets:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_DEFAULT_REGION
```

For example:

```text
AWS_DEFAULT_REGION = us-east-1
```

---

## 2. Open GitHub Codespaces Settings

In GitHub:

1. Click your profile picture.
2. Select **Settings**.
3. Select **Codespaces**.
4. Find **Codespaces secrets**.
5. Click **New secret**.

---

## 3. Create `AWS_ACCESS_KEY_ID`

Create a secret named:

```text
AWS_ACCESS_KEY_ID
```

Enter the AWS access key as the secret value.

Under **Repository access**, give access only to the repository that needs the credential.

Save the secret.

---

## 4. Create `AWS_SECRET_ACCESS_KEY`

Create another secret named:

```text
AWS_SECRET_ACCESS_KEY
```

Enter the AWS secret access key as the value.

Give it access to the same repository and save the secret.

---

## 5. Create `AWS_DEFAULT_REGION`

Create another Codespaces secret:

```text
AWS_DEFAULT_REGION
```

For example:

```text
us-east-1
```

Give it access to the same repository and save the secret.

---

## 6. Restart the Codespace

If the Codespace was already running when the secrets were created or modified:

1. Save the secret changes on GitHub.
2. Stop the Codespace.
3. Start the Codespace again.

Opening another terminal tab is not the same as restarting the Codespace. The secrets are injected as environment variables only at startup.

---

## 7. Verify the Secrets Are Available

Do not print the actual AWS secret values. Instead, check whether the variables exist:

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

## 8. Verify AWS Authentication

Run:

```bash
aws sts get-caller-identity
```

If authentication is working correctly, AWS returns information about the account and IAM identity being used, for example:

```json
{
    "UserId": "AIДА...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-iam-user"
}
```

---

## 9. Do Not Store Credentials in Terraform

Do not configure the AWS provider like this:

```hcl
# BAD — never do this
provider "aws" {
  access_key = "YOUR_ACCESS_KEY"
  secret_key = "YOUR_SECRET_KEY"
}
```

The Terraform AWS provider should read credentials from the environment automatically:

```hcl
# GOOD
provider "aws" {
  region = var.aws_region
}
```

---

## 10. Do Not Commit AWS Credentials

Never commit AWS credentials to any file, including:

```text
main.tf
variables.tf
terraform.tfvars
.env
README.md
*.sh
```

---

## Authentication Flow

```text
GitHub Codespaces Secrets
        |
        v
Codespace Environment Variables
        |
        +---> AWS_ACCESS_KEY_ID
        +---> AWS_SECRET_ACCESS_KEY
        +---> AWS_DEFAULT_REGION
        |
        v
AWS CLI / Terraform
        |
        v
AWS
```

This keeps AWS credentials outside the Terraform source code and the Git repository.

# Secure AWS Credentials in Gi*Hub Codespaces

This guide explains how to securely provide AWS credentials to AWS CLI and Terraform using GitHub Codespaces secrets.

AWS credentials should never be committed to the repository.

---

# 1. Required AWS Secrets

Create the foll*wing GitHub Codespaces secrets:

`*`text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_DEFAULT_REGION
```
*For example:

```text
AWS_DEFAULT_REGION = us-east-1
```

---

# 2. Open GitHub Codespaces Settings

In gitHub:

1. Click your profile picture.
2. Select **Settings**.
3. Sel*ct **Codespaces**.
4. Find **Codespaces secrets**.
5. Click **New secret**.

---

# 3. Create `AWS_ACCESS_KEY_ID`

Create a secret named:

*``text
AWS_ACCESS_KEY_ID
```

Enter the AWS access key as the secret value.

Under **Repository access*** give access only to the repository that needs the credential.

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

*``text
Andrey242-GH/EC2_Heartbeat_AWS_Infrastructure
```

Save the secret.

---

# 5. Configure the AWS region

Create another Codespaces secret:

```text
AWS_DEFAULT_REGION
*``

For example:

```text
us-east-1
```

Give the secret access to the same repository.

---

# 6. Restart the Codespace

If the Codespace *as already running when the secret* were created or modified:

1. Save the secret changes.
2. Stop the Codespace.
3. Start the Codespace again.

Opening another terminal is n*t the same as restarting the Codes*ace.

---

# 7. Verify That the Se*rets Are Available

Do not print t*e actual AWS secret values.

Inste*d, check whether the variables exi*t:

```bash
if [ -n "${AWS_ACCESS_KEY_ID:-}" ]; then
    echo "AWS_AC*ESS_KEY_ID configured"
else
    ec*o "AWS_ACCESS_KEY_ID missing"
fi

*f [ -n "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    echo "AWS_SECRET_ACCE*S_KEY configured"
else
    echo "A*S_SECRET_ACCESS_KEY missing"
fi
``*

Expected output:

```text
AWS_AC*ESS_KEY_ID configured
AWS_SECRET_A*CESS_KEY configured
```

Check the*region:

```bash
echo "${AWS_DEFAU*T_REGION:-AWS_DEFAULT_REGION is no* configured}"
```

---

# 8. Verif* AWS Authentication

Run:

```bash*aws sts get-caller-identity
```

I* authentication is working correct*y, AWS will return information abo*t the AWS account and IAM identity*being used.

---

# 9. Do Not Stor* Credentials in Terraform

Do not *onfigure the AWS provider like thi*:

```hcl
provider "aws" {
  acces*_key = "YOUR_ACCESS_KEY"
  secret_*ey = "YOUR_SECRET_KEY"
}
```

The *erraform AWS provider should use t*e credentials provided by the envi*onment instead.

For example:

```*cl
provider "aws" {
  region = var*aws_region
}
```

---

# 10. Do No* Commit AWS Credentials

Never com*it AWS credentials to files such a*:

```text
main.tf
providers.tf
va*iables.tf
terraform.tfvars
.env
RE*DME.md
*.sh
```

---

# Authentica*ion Flow

The authentication flow *or this project is:

```text
GitHu* Codespaces Secrets
        |
    *   v
Codespace Environment Variabl*s
        |
        +--> AWS_ACCES*_KEY_ID
        |
        +--> AWS*SECRET_ACCESS_KEY
        |
      * +--> AWS_DEFAULT_REGION
        |*        v
AWS CLI / Terraform
    *   |
        v
AWS
```

This keeps*AWS credentials outside the Terraf*rm source code and Git repository.*
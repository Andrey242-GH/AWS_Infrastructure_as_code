# Create the AWS VPC and subnets with Terraform

This configuration reproduces the resources in `AWS_CLI/Create.sh`:

- VPC `10.0.0.0/16`, tagged `my-codeCreatedVPC`
- `Public_Subnet_1`: `10.0.1.0/24` in `us-east-1a`
- `Private_Subnet_1`: `10.0.10.0/24` in `us-east-1a`
- `Public_Subnet_2`: `10.0.2.0/24` in `us-east-1b`

Terraform stores the resource IDs in its state and exposes them as outputs.
AWS credentials are read from the normal AWS credential chain; do not put
access keys in Terraform files or commit state files.

## Create a new deployment

From the repository root, authenticate to the intended AWS account and review
the caller identity:

```bash
aws sts get-caller-identity
cd Terraform
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform show tfplan
```

If the plan contains only the resources you intend to create, apply it:

```bash
terraform apply tfplan
```

Show the VPC and subnet IDs:

```bash
terraform output
```

To remove the resources managed by this Terraform state, review the destroy
plan before confirming:

```bash
terraform plan -destroy
terraform destroy
```

## Manage resources previously created by `Create.sh`

Terraform does not automatically discover resources created by the AWS CLI.
If those resources already exist, do **not** run `terraform apply` with a new,
empty Terraform state: it will try to create another VPC and subnets.

Instead, import the existing resources into Terraform state. Replace each
placeholder with the corresponding ID from `AWS_CLI/Resources.env`:

```bash
cd Terraform
terraform init
terraform import aws_vpc.main <VPC_ID>
terraform import 'aws_subnet.subnets["Public_Subnet_1"]' <PUBLIC_SUBNET_1_ID>
terraform import 'aws_subnet.subnets["Private_Subnet_1"]' <PRIVATE_SUBNET_1_ID>
terraform import 'aws_subnet.subnets["Public_Subnet_2"]' <PUBLIC_SUBNET_2_ID>
terraform plan
```

Review the plan and confirm it does not propose unexpected changes before
applying. Importing records the existing resources in Terraform state; it does
not create or delete AWS resources.

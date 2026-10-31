# Create the AWS Network Infrastructure with Terraform

This configuration creates the following resources:

- VPC `10.0.0.0/16`, tagged `my-codeCreatedVPC`
- `Public_Subnet_1`: `10.0.1.0/24` in `us-east-1a`
- `Private_Subnet_1`: `10.0.10.0/24` in `us-east-1a`
- `Public_Subnet_2`: `10.0.2.0/24` in `us-east-1b`
- Internet Gateway attached to the VPC
- Public route table with a `0.0.0.0/0` → IGW route
- Route table associations for both public subnets

Terraform stores the resource IDs in its state and exposes them as outputs.
AWS credentials are read from the environment; do not put access keys in
Terraform files or commit state files.

## Create a new deployment

Authenticate to the intended AWS account, then run:

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

Show all created resource IDs:

```bash
terraform output
```

To remove all resources managed by this Terraform state:

```bash
terraform plan -destroy
terraform destroy
```

## Manage resources previously created by `Create.sh`

Terraform does not automatically discover resources created by the AWS CLI.
If those resources already exist, do **not** run `terraform apply` with a new
empty Terraform state — it will try to create duplicates.

Instead, import the existing resources into Terraform state. Replace each
placeholder with the corresponding ID from `AWS_CLI/Resources.env`:

```bash
cd Terraform
terraform init
terraform import aws_vpc.main                              <VPC_ID>
terraform import 'aws_subnet.subnets["Public_Subnet_1"]'  <SUBNET_Public_Subnet_1_ID>
terraform import 'aws_subnet.subnets["Private_Subnet_1"]' <SUBNET_Private_Subnet_1_ID>
terraform import 'aws_subnet.subnets["Public_Subnet_2"]'  <SUBNET_Public_Subnet_2_ID>
terraform import aws_internet_gateway.main                 <IGW_ID>
terraform import aws_route_table.public                    <RTB_ID>
terraform plan
```

Review the plan and confirm it shows no unexpected changes before applying.
Importing records existing resources in Terraform state; it does not create
or delete any AWS resources.

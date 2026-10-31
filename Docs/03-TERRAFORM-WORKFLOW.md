# AWS Infrastructure Workflow — AWS CLI and Terraform

This guide explains the full workflow for creating, inspecting, modifying, and
destroying the AWS network infrastructure using the two approaches this project
provides:

- **AWS CLI** — the bash scripts in `AWS_CLI/` (`Create.sh` and `Delete.sh`) call
  the AWS API directly and track resource IDs in `Resources.env`.
- **Terraform** — the configuration in `Terraform/` manages the same resources
  through its state file.

Both build identical infrastructure. Use whichever you prefer, but do **not**
point both at the same resources at the same time — if resources already exist
from one tool, import them into the other before managing them (see
[Importing existing CLI resources into Terraform](#importing-existing-cli-resources-into-terraform)).

---

## 1. Verify AWS Authentication

Both approaches need valid AWS credentials configured in the environment.
Verify which identity is in use before running anything:

```bash
aws sts get-caller-identity
```

Make sure the command returns the AWS account and IAM identity you expect to
use. For setup, see [02-AWS-CREDENTIALS-CODESPACES.md](02-AWS-CREDENTIALS-CODESPACES.md).

---

# Part A — AWS CLI (bash scripts)

The scripts call the AWS CLI directly and record every created resource ID in
`AWS_CLI/Resources.env` so the same resources can be deleted later. There is no
state file — `Resources.env` is the only record of what was created.

## A.1 Prerequisites

- AWS CLI v2 installed and authenticated
- `jq` installed (`Create.sh` parses the subnet definitions with `jq`)

Check `jq`:

```bash
jq --version
```

If it is missing, install it:

```bash
sudo apt-get update && sudo apt-get install -y jq
```

## A.2 Files

| File | Purpose |
|---|---|
| `AWS_CLI/Create.sh` | Creates the VPC, subnets, internet gateway, route table, and associations; saves IDs to `Resources.env` |
| `AWS_CLI/Delete.sh` | Reads `Resources.env` and deletes everything in the correct dependency order |
| `AWS_CLI/Resources.env` | Auto-generated `key=value` file storing resource IDs between runs (do not edit by hand) |

## A.3 Create the infrastructure

From the repository root:

```bash
bash AWS_CLI/Create.sh
```

Or from inside the directory:

```bash
cd AWS_CLI
bash Create.sh
```

The script does the following, in order:

1. If `Resources.env` already exists and is non-empty, it automatically runs
   `Delete.sh` first so you start from a clean state.
2. Creates the VPC `10.0.0.0/16` and tags it `my-codeCreatedVPC`.
3. Creates three subnets and tags them.
4. Creates the Internet Gateway, tags it `my-codeCreatedIGW`, and attaches it to
   the VPC.
5. Creates the public route table, adds the `0.0.0.0/0` → IGW route.
6. Associates only the public subnets with the route table.
7. Writes every resource ID to `Resources.env` and prints them.

Optional: point the scripts at a different ID file (the default is
`AWS_CLI/Resources.env`):

```bash
bash AWS_CLI/Create.sh /path/to/my-resources.env
bash AWS_CLI/Delete.sh /path/to/my-resources.env
```

## A.4 Inspect what was created

View the saved resource IDs:

```bash
cat AWS_CLI/Resources.env
```

The file contains lines such as:

```text
REGION=us-east-1
VPC_ID=vpc-0123456789abcdef0
SUBNET_Public_Subnet_1_ID=subnet-...
SUBNET_Private_Subnet_1_ID=subnet-...
SUBNET_Public_Subnet_2_ID=subnet-...
IGW_ID=igw-...
RTB_ID=rtb-...
RTB_ASSOC_Public_Subnet_1_ID=rtbassoc-...
RTB_ASSOC_Public_Subnet_2_ID=rtbassoc-...
```

You can also inspect the resources directly with the AWS CLI, for example:

```bash
aws ec2 describe-vpcs --vpc-ids <VPC_ID>
aws ec2 describe-subnets --filters Name=vpc-id,Values=<VPC_ID>
```

## A.5 Delete the infrastructure

```bash
bash AWS_CLI/Delete.sh
```

The script reads `Resources.env`, validates every ID, prints a summary of what
will be deleted, and asks you to type `DELETE` to confirm. It then removes
resources in the correct dependency order so AWS does not reject the deletion:

1. Disassociate the route table from the subnets
2. Delete the route table
3. Detach and delete the Internet Gateway
4. Delete the subnets
5. Delete the VPC
6. Clear `Resources.env`

If you type anything other than `DELETE`, nothing is deleted.

---

# Part B — Terraform

Terraform manages the same resources through its state file and resolves
dependency and deletion order automatically.

## B.1 Verify Terraform

```bash
terraform --version
```

## B.2 Go to the Terraform project

Navigate to the Terraform directory:

```bash
cd /workspaces/AWS_Infrastructure_as_code/Terraform
```

Check the files:

```bash
ls
```

A Terraform project typically contains files such as:

```text
main.tf
variables.tf
outputs.tf
.terraform.lock.hcl
```

## B.3 Initialize Terraform

Initialize the Terraform project:

```bash
terraform init
```

Terraform prepares the working directory and installs the providers required by
the configuration. Run this once when you first clone the repository, and again
whenever you add or change a provider.

## B.4 Format Terraform files

Format the Terraform files:

```bash
terraform fmt
```

Check that everything is correctly formatted without making changes:

```bash
terraform fmt -check
```

## B.5 Validate the configuration

Before creating infrastructure, validate the configuration:

```bash
terraform validate
```

The configuration should pass validation before continuing.

## B.6 Create an infrastructure plan

Preview what Terraform intends to create, modify, or destroy:

```bash
terraform plan
```

Review the output carefully. Lines starting with `+` mean a resource will be
created, `-` means it will be destroyed, and `~` means it will be modified in
place.

## B.7 Save the Terraform plan

Save the plan to a file to guarantee that exactly what you reviewed is what gets
applied:

```bash
terraform plan -out=tfplan
```

Review the saved plan:

```bash
terraform show tfplan
```

Make sure the proposed changes are correct before applying them.

## B.8 Apply the plan

Apply the saved Terraform plan:

```bash
terraform apply tfplan
```

Terraform will execute exactly the operations contained in the saved plan.

## B.9 View managed resources

After deployment, list all resources currently tracked in Terraform state:

```bash
terraform state list
```

## B.10 View Terraform outputs

Display all configured outputs:

```bash
terraform output
```

Display a single output by name:

```bash
terraform output <output_name>
```

For example:

```bash
terraform output vpc_id
terraform output subnet_ids
terraform output internet_gateway_id
terraform output public_route_table_id
```

## B.11 Modify existing infrastructure

When modifying Terraform configuration, first edit the appropriate `.tf` files,
then run:

```bash
terraform fmt
terraform validate
terraform plan
```

Review the proposed changes. If everything looks correct:

```bash
terraform apply
```

Terraform calculates the differences between the configuration and the current
state and applies only what changed.

## B.12 Destroy the infrastructure

Before destroying infrastructure, preview what Terraform intends to remove:

```bash
terraform plan -destroy
```

Review the destruction plan carefully. If the correct resources are listed:

```bash
terraform destroy
```

Terraform will ask for confirmation. Type `yes` only after reviewing the
resources that will be destroyed.

## B.13 Verify the infrastructure was destroyed

After Terraform finishes:

```bash
terraform state list
```

The output should be empty. You can also verify in the AWS console that the
expected resources no longer exist.

---

## Importing existing CLI resources into Terraform

Terraform does not automatically discover resources created by the AWS CLI. If
those resources already exist (for example from running `Create.sh`), do **not**
run `terraform apply` with a new empty Terraform state — it will try to create
duplicates. Import the existing resources into Terraform state first. Replace
each placeholder with the corresponding ID from `AWS_CLI/Resources.env`:

```bash
cd Terraform
terraform init
terraform import aws_vpc.main                               <VPC_ID>
terraform import 'aws_subnet.subnets["Public_Subnet_1"]'   <SUBNET_Public_Subnet_1_ID>
terraform import 'aws_subnet.subnets["Private_Subnet_1"]'  <SUBNET_Private_Subnet_1_ID>
terraform import 'aws_subnet.subnets["Public_Subnet_2"]'   <SUBNET_Public_Subnet_2_ID>
terraform import aws_internet_gateway.main                 <IGW_ID>
terraform import aws_route_table.public                    <RTB_ID>
terraform plan
```

Review the plan and confirm it shows no unexpected changes before applying.
Importing records existing resources in Terraform state; it does not create or
delete any AWS resources.

---

## Standard workflows

### AWS CLI — create

```bash
aws sts get-caller-identity
bash AWS_CLI/Create.sh
cat AWS_CLI/Resources.env
```

### AWS CLI — delete

```bash
bash AWS_CLI/Delete.sh
```

### Terraform — create

```bash
aws sts get-caller-identity
cd Terraform
terraform init
terraform fmt
terraform validate
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
terraform output
```

### Terraform — modify

```bash
# After editing .tf files:
terraform fmt
terraform validate
terraform plan
terraform apply
```

### Terraform — destroy

```bash
terraform plan -destroy
terraform destroy
```

---

## Useful commands

### AWS CLI scripts

| Command | What it does |
|---|---|
| `bash AWS_CLI/Create.sh` | Creates all resources and saves IDs to `Resources.env` |
| `bash AWS_CLI/Create.sh <file>` | Uses a custom ID file instead of `Resources.env` |
| `bash AWS_CLI/Delete.sh` | Reads `Resources.env` and deletes everything (asks for confirmation) |
| `bash AWS_CLI/Delete.sh <file>` | Deletes resources tracked in a custom ID file |
| `cat AWS_CLI/Resources.env` | Shows the IDs of the currently created resources |

### Terraform

| Command | What it does |
|---|---|
| `terraform init` | Installs providers and prepares the working directory |
| `terraform fmt` | Formats `.tf` files to canonical style |
| `terraform fmt -check` | Checks formatting without changing files |
| `terraform validate` | Validates configuration syntax and logic |
| `terraform plan` | Shows what will be created, changed, or destroyed |
| `terraform plan -out=tfplan` | Saves a plan to a file |
| `terraform show tfplan` | Displays the saved plan |
| `terraform apply` | Applies changes (asks for confirmation) |
| `terraform apply tfplan` | Applies a saved plan (no confirmation prompt) |
| `terraform state list` | Lists all resources in state |
| `terraform output` | Displays all output values |
| `terraform plan -destroy` | Previews a full destroy |
| `terraform destroy` | Destroys all managed resources |
| `terraform import <addr> <id>` | Records an existing AWS resource into state |

---

## Important rules

Always review before making changes — never apply or destroy blindly:

```text
Plan  →  Review  →  Apply
```

```text
Plan Destroy  →  Review  →  Destroy
```

For the AWS CLI scripts, the equivalent safety check is the `DELETE`
confirmation prompt in `Delete.sh` and the automatic cleanup that `Create.sh`
runs when `Resources.env` already contains resources.

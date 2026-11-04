# Create the AWS Network Infrastructure with Terraform

This configuration creates the following resources:

**Network**
- VPC `10.0.0.0/16`, tagged `my-codeCreatedVPC`
- `Public_Subnet_1`: `10.0.1.0/24` in `us-east-1a` — auto-assign public IPv4 enabled
- `Private_Subnet_1`: `10.0.10.0/24` in `us-east-1a`
- `Public_Subnet_2`: `10.0.2.0/24` in `us-east-1b` — auto-assign public IPv4 enabled
- Internet Gateway attached to the VPC
- Elastic IP address for the NAT Gateway
- NAT Gateway placed in `Public_Subnet_1`
- Public route table with a `0.0.0.0/0` → IGW route, associated to both public subnets
- Private route table with a `0.0.0.0/0` → NAT Gateway route, associated to `Private_Subnet_1`

**Compute**
- Security group `ec2_HeartBeat` — SSH (port 22) and HTTP (port 80) open from `0.0.0.0/0`, all outbound allowed
- `Bastion_Host` — `t2.micro` in `Public_Subnet_1`, public IP via subnet auto-assign, shutdown = terminate
- `Private_HeartBeat_1` and `Private_HeartBeat_2` — `t2.micro` in `Private_Subnet_1`, public IP explicitly assigned at launch, shutdown = terminate
- All three instances run the Heartbeat Automation app via user-data (Amazon Linux 2023)

Terraform stores the resource IDs in its state and exposes them as outputs.
AWS credentials are read from the environment; do not put access keys in
Terraform files or commit state files.

> **Cost warning:** NAT Gateways (~$0.045/hr) and EC2 instances accrue charges
> while running. Run `terraform destroy` when you are done to avoid unexpected
> charges.

## Variables

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | Region to deploy into |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `vpc_name` | `my-codeCreatedVPC` | Name tag on the VPC |
| `instance_type` | `t2.micro` | EC2 instance type for all instances |
| `key_name` | `""` | Existing EC2 key pair name; leave empty to launch without one |

To override a variable at plan time:

```bash
terraform plan -var="key_name=my-keypair" -out=tfplan
```

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

Show all created resource IDs and IP addresses:

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
terraform import aws_vpc.main                                         <VPC_ID>
terraform import 'aws_subnet.subnets["Public_Subnet_1"]'             <SUBNET_Public_Subnet_1_ID>
terraform import 'aws_subnet.subnets["Private_Subnet_1"]'            <SUBNET_Private_Subnet_1_ID>
terraform import 'aws_subnet.subnets["Public_Subnet_2"]'             <SUBNET_Public_Subnet_2_ID>
terraform import aws_internet_gateway.main                            <IGW_ID>
terraform import aws_eip.nat                                          <EIP_ALLOC_ID>
terraform import aws_nat_gateway.main                                 <NATGW_ID>
terraform import aws_route_table.public                               <RTB_ID>
terraform import aws_route_table.private                              <PRIVATE_RTB_ID>
terraform import aws_security_group.ec2_heartbeat                    <SG_ID>
terraform import aws_instance.bastion                                 <BASTION_ID>
terraform import 'aws_instance.private[0]'                           <PRIVATE_INSTANCE_1_ID>
terraform import 'aws_instance.private[1]'                           <PRIVATE_INSTANCE_2_ID>
terraform plan
```

Review the plan and confirm it shows no unexpected changes before applying.
Importing records existing resources in Terraform state; it does not create
or delete any AWS resources.

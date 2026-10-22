# Terr*form Infrastructure Workflow

This*guide explains the normal workflow*for creating, modifying, inspectin*, and destroying AWS infrastructur* managed by Terraform.

---

# 1. *erify AWS Authentication

Before r*nning Terraform, verify which AWS *dentity is being used:

```bash
aw* sts get-caller-identity
```

Make*sure the command returns the AWS a*count and IAM identity that you ex*ect to use.

---

# 2. Verify Terr*form

```bash
terraform --version
*``

---

# 3. Go to the Terraform *roject

Navigate to the directory *ontaining the Terraform files.

Fo* example:

```bash
cd /workspaces/*C2_Heartbeat_AWS_Infrastructure
``*

Check the files:

```bash
ls
```*
A Terraform project may contain f*les such as:

```text
main.tf
prov*ders.tf
variables.tf
outputs.tf
te*raform.tfvars
user-data.sh
```

--*

# 4. Initialize Terraform

Initi*lize the Terraform project:

```ba*h
terraform init
```

Terraform pr*pares the working directory and in*talls the providers required by th* configuration.

---

# 5. Format *erraform Files

Format the Terrafo*m files:

```bash
terraform fmt
``*

Check that everything is correct*y formatted:

```bash
terraform fm* -check
```

---

# 6. Validate th* Configuration

Before creating in*rastructure:

```bash
terraform va*idate
```

The configuration shoul* pass validation before continuing*

---

# 7. Create an Infrastructu*e Plan

Preview what Terraform int*nds to create, modify, or destroy:*
```bash
terraform plan
```

Revie* the output carefully.

---

# 8. *ave the Terraform Plan

A useful w*rkflow is to save the Terraform pl*n:

```bash
terraform plan -out=tf*lan
```

Review the saved plan:

`*`bash
terraform show tfplan
```

M*ke sure the proposed infrastructur* changes are correct before applyi*g them.

---

# 9. Create the Infr*structure

Apply the saved Terrafo*m plan:

```bash
terraform apply t*plan
```

Terraform will execute t*e operations contained in the save* plan.

---

# 10. View Terraform *esources

After deployment:

```ba*h
terraform state list
```

This d*splays resources currently represe*ted in the Terraform state.

---

* 11. View Terraform Outputs

Displ*y all configured outputs:

```bash*terraform output
```

Display an i*dividual output:

```bash
terrafor* output <output_name>
```

For exa*ple:

```bash
terraform output ins*ance_public_ip
```

---

# Modify *xisting Infrastructure

When modif*ing Terraform configuration, first*edit the appropriate `.tf` files.
*Then run:

```bash
terraform fmt
t*rraform validate
terraform plan
``*

Review the proposed changes.

If*everything looks correct:

```bash*terraform apply
```

Terraform wil* calculate the differences between*the configuration and the infrastr*cture represented by its state.

-*-

# Destroy the Infrastructure

B*fore destroying infrastructure, pr*view what Terraform intends to rem*ve.

Run:

```bash
terraform plan *destroy
```

Review the destructio* plan carefully.

If the correct r*sources are going to be destroyed:*
```bash
terraform destroy
```

Te*raform will ask for confirmation.
*Enter:

```text
yes
```

only afte* reviewing the resources that Terr*form intends to destroy.

---

# V*rify the Infrastructure Was Destro*ed

After Terraform finishes:

```*ash
terraform state list
```

Also*verify the expected resources in A*S.

---

# Standard Infrastructure*Creation Workflow

```bash
# Verif* AWS credentials and identity
aws sts get-caller-identity

# Initialize Terraform
terraform init

# Format configuration
terraform fmt

# Validate configuration
terraform validate

# Create a saved plan
terraform plan -out=tfplan

# Review the plan
terraform show tfplan

# Create/update infrastructure
terraform apply tfplan
```

---

# Standard Infrastructure Modification Workflow

After changing the Terraform configuration:

```bash
terraform fmt
terraform validate
terraform plan
terraform apply
```

Always review the plan before approving the changes.

---

# Standard Infrastructure Destruction Workflow

Preview the destruction:

```bash
terraform plan -destroy
```

Then destroy the infrastructure:

```bash
terraform destroy
```

---

# Useful Terraform Commands

## Initialize the Project

```bash
terraform init
```

## Format Terraform Files

```bash
terraform fmt
```

## Validate Terraform

```bash
terraform validate
```

## Preview Changes

```bash
terraform plan
```

## Save a Plan

```bash
terraform plan -out=tfplan
```

## View a Saved Plan

```bash
terraform show tfplan
```

## Apply Changes

```bash
terraform apply
```

## Apply a Saved Plan

```bash
terraform apply tfplan
```

## View Managed Resources

```bash
terraform state list
```

## View Outputs

```bash
terraform output
```

## Preview Infrastructure Destruction

```bash
terraform plan -destroy
```

## Destroy Infrastructure

```bash
terraform destroy
```

---

# Recommended Workflow

For creating or changing infrastructure:

```text
Verify AWS Identity
        |
        v
terraform init
        |
        v
terraform fmt
        |
        v
terraform validate
        |
        v
terraform plan
        |
        v
Review Changes
        |
        v
terraform apply
```

For destroying infrastructure:

```text
terraform plan -destroy
        |
        v
Review Resources
        |
        v
terraform destroy
```

---

# Important Rule

Always follow this process:

```text
PLAN
  |
  v
REVIEW
  |
  v
APPLY
```

For destroying resources:

```text
PLAN DESTROY
     |
     v
REVIEW
     |
     v
DESTROY
```

Do not blindly apply or destroy infrastructure without reviewing what Terraform intends to change.
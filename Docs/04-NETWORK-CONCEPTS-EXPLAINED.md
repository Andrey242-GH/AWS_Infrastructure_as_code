# AWS Networking & Compute Concepts — A Beginner's Guide

This document explains every networking and compute concept used in this project, from scratch. It assumes you have never built cloud infrastructure before. Each section explains **what the thing is**, **why it exists**, and **how it connects to everything else**.

---

## The Big Picture — What Are We Building?

Before diving into individual pieces, here is the full picture of what this project creates and why.

Imagine you are setting up a secure office building:

- The **building** is your **VPC** — it is your private space, separated from everyone else
- The **rooms** inside the building are your **subnets** — different areas for different purposes
- The **front door** to the outside world is the **Internet Gateway**
- The **security desk** that lets back-room workers reach the internet but keeps outsiders out of the back rooms is the **NAT Gateway**
- The **directory on the wall** telling people which room to go to is the **Route Table**
- The **reception desk** where all visitors must check in before going anywhere else is the **Bastion Host**
- The **door policy** controlling who is allowed in is the **Security Group**
- The **room numbers** are **IP addresses**

Everything in this project exists to recreate that structure in AWS. Let's go through each piece.

---

## 1. IP Addresses and CIDR Notation

### What is an IP address?

Every device on a network needs an address so other devices know how to send it data. An IP address is that address. It looks like four numbers separated by dots:

```
10.0.1.45
```

Each number goes from 0 to 255. Think of it like a postal address — the network needs to know exactly where to deliver packets of data.

### What is CIDR notation?

CIDR (pronounced "cider") is a way of describing a **range** of IP addresses rather than a single one. It looks like an IP address with a slash and a number at the end:

```
10.0.0.0/16
```

The number after the slash tells you how many bits of the address are **fixed** (the network part) and how many are **free to use** (the host part).

You don't need to understand binary to use this — just remember these common sizes:

| CIDR | Number of addresses | Typical use |
|---|---|---|
| /16 | 65,536 | A whole VPC |
| /24 | 256 | A single subnet |
| /32 | 1 | A single specific IP address |
| 0.0.0.0/0 | All addresses | "Anywhere on the internet" |

**In this project:**
- The VPC uses `10.0.0.0/16` — 65,536 addresses for the whole network
- Each subnet carves out a /24 chunk from inside that range:
  - `10.0.1.0/24` — Public Subnet 1
  - `10.0.2.0/24` — Public Subnet 2
  - `10.0.10.0/24` — Private Subnet 1

The subnets are all smaller ranges that fit inside the bigger VPC range. Think of the VPC range as the whole building, and the subnets as individual floors.

---

## 2. VPC — Virtual Private Cloud

### What is a VPC?

A VPC is your own **private, isolated section of the AWS network**. When you create a VPC, AWS gives you a completely separate network that no other AWS customer can see or access.

Before VPCs existed, everyone shared the same flat network inside AWS — a bit like living in a house with no locks. VPCs were introduced to give every customer their own walled space.

### What does it actually do?

The VPC defines:
- The **overall IP address range** for everything inside it (in this project: `10.0.0.0/16`)
- A **boundary** — nothing gets in or out unless you explicitly allow it
- A **container** for all your other networking resources (subnets, route tables, gateways)

### Why does it need a CIDR block?

The CIDR block (`10.0.0.0/16`) is the pool of IP addresses available to everything inside the VPC. Every subnet, every server, every database inside the VPC gets an IP address from this pool. You need to define the pool upfront so AWS knows what range to work with.

### In this project

```
Name:  my-codeCreatedVPC
CIDR:  10.0.0.0/16
```

---

## 3. Subnets

### What is a subnet?

A subnet (short for **sub-network**) is a smaller network carved out of the VPC. It is a way of dividing your VPC into sections for different purposes.

Think of the VPC as a large plot of land. Subnets are the individual buildings you construct on that land. Each building has its own address range, but they are all on the same plot.

### Why do we divide into subnets?

Two reasons:

**1. Security separation**
Some resources should be reachable from the internet (like a web server or bastion host). Others should never be directly reachable from the internet (like application servers or databases). By putting them in separate subnets, you can apply different routing rules to each.

**2. Availability zones**
AWS data centres are grouped into **Availability Zones** (AZs). An AZ is essentially a separate physical building with its own power, cooling, and networking. Each subnet can only live in one AZ. By creating subnets in different AZs, your application stays online even if one data centre has a problem.

### Public vs Private subnets

This is one of the most important concepts in cloud networking:

| | Public subnet | Private subnet |
|---|---|---|
| Directly reachable from the internet? | Yes | No (by default) |
| Can reach the internet? | Yes, directly via IGW | Yes, indirectly via NAT Gateway |
| Typical use | Web servers, load balancers, bastion hosts, NAT Gateway | App servers, databases, backend services |

The label "public" or "private" is not a built-in AWS setting on the subnet itself. A subnet becomes public when you:
1. Connect it to a route table that has a route to an Internet Gateway
2. Enable auto-assign public IPv4

A subnet is private when it routes internet traffic through a NAT Gateway instead.

### What is auto-assign public IPv4?

By default, when you launch a server (EC2 instance) in a subnet, it only gets a **private IP address** — one that only works inside the VPC. Nobody on the internet can reach it.

When you enable **auto-assign public IPv4** on a subnet, every instance launched there automatically also gets a **public IP address** — one that works on the real internet. This is what makes web servers and bastion hosts reachable without any extra steps.

Private subnets do NOT have this enabled at the subnet level. However, you can still explicitly request a public IP for a specific instance at launch time — which is exactly what this project does for the two private Heartbeat instances so the bastion pattern can reach them.

### In this project

```
Public_Subnet_1   10.0.1.0/24   us-east-1a   auto-assign public IPv4: YES (subnet-level)
Public_Subnet_2   10.0.2.0/24   us-east-1b   auto-assign public IPv4: YES (subnet-level)
Private_Subnet_1  10.0.10.0/24  us-east-1a   auto-assign public IPv4: NO  (instance override: YES)
```

---

## 4. Internet Gateway (IGW)

### What is an Internet Gateway?

The Internet Gateway is the **door between your VPC and the public internet**. Without it, nothing inside your VPC can communicate with anything outside — and nothing outside can reach in.

It is a fully managed AWS component. You do not configure it, patch it, or scale it — AWS handles all of that. You just create it and attach it to your VPC.

### Why does it need to be attached to the VPC?

AWS needs to know which VPC this door belongs to. A VPC can only have one Internet Gateway. You attach them together to form the connection.

### Is attaching the IGW enough to get internet access?

No. Attaching the IGW is just installing the door. You also need to tell your subnets to **use** that door — that is what route tables are for (see Section 6).

Think of it this way: you can install a front door on a building, but if there are no signs or corridors telling people how to reach it, no one will use it.

### In this project

```
Name: my-codeCreatedIGW
Attached to: my-codeCreatedVPC
```

---

## 5. Elastic IP Address (EIP)

### What is an Elastic IP?

A regular public IP address given to an AWS resource can change every time you stop and start it. An **Elastic IP** is a **static, permanent public IP address** that belongs to your AWS account until you explicitly release it.

"Elastic" means you can move it around — you can detach it from one resource and attach it to another without changing the address itself.

### Why does the NAT Gateway need one?

The NAT Gateway needs a **fixed public IP** because it acts as the shared exit point for all servers in the private subnet. When those servers make requests to the internet, the response needs to know where to come back to. If the IP kept changing, responses would never find their way back.

### Important — Elastic IPs cost money when not in use

AWS charges for Elastic IPs that are allocated but not attached to a running resource. If you delete your NAT Gateway without releasing the EIP, you will keep paying for it. The Delete script in this project handles this correctly.

### In this project

```
Name: my-codeCreatedNATGW-EIP
Used by: my-codeCreatedNATGW (NAT Gateway)
```

---

## 6. Route Tables

### What is a route table?

A route table is like a **GPS or a directory** inside your network. It contains a list of rules (called **routes**) that tell network traffic: "if you are trying to reach address X, go in this direction."

Every subnet in a VPC must be associated with exactly one route table. When a packet of data arrives at a subnet trying to go somewhere, the subnet looks up the destination in its route table and follows the directions.

### What does a route look like?

A route has two parts:

| Part | Example | Meaning |
|---|---|---|
| Destination | `0.0.0.0/0` | The range of addresses this rule applies to |
| Target | `igw-abc123` | Where to send traffic going to those addresses |

The destination `0.0.0.0/0` means "any address" — it is the catch-all rule that handles all traffic that doesn't match a more specific route. This is sometimes called the **default route**.

### The local route — always present

Every route table automatically has one built-in route:

```
Destination: 10.0.0.0/16    Target: local
```

This rule means "anything going to an address inside this VPC, deliver it internally." This is how servers in different subnets can talk to each other without going out to the internet.

### Why do public and private subnets need different route tables?

Because they need different behaviour for internet-bound traffic:

- **Public subnets**: send internet traffic → Internet Gateway (direct, two-way connection)
- **Private subnets**: send internet traffic → NAT Gateway (indirect, outbound-only)

If you put both in the same route table, you cannot give them different rules.

### Route table associations

Creating a route table does not automatically apply it to any subnet. You have to **associate** the route table with each subnet explicitly. Think of it as: you created the directory, now you have to hang it on the wall of each room that should use it.

### In this project

**Public Route Table** — associated with Public_Subnet_1 and Public_Subnet_2:
```
Destination     Target
10.0.0.0/16     local          (VPC-internal traffic)
0.0.0.0/0       igw-xxxxx      (everything else → Internet Gateway)
```

**Private Route Table** — associated with Private_Subnet_1:
```
Destination     Target
10.0.0.0/16     local          (VPC-internal traffic)
0.0.0.0/0       nat-xxxxx      (everything else → NAT Gateway)
```

---

## 7. NAT Gateway

### What is a NAT Gateway?

NAT stands for **Network Address Translation**. The NAT Gateway lets servers in **private subnets reach the internet**, while keeping them completely hidden from inbound connections.

Here is the problem it solves: your private application server needs to clone a git repo and download Python packages during setup. But it has no public IP address, so the internet does not know how to reply to it. The NAT Gateway solves this by acting as a **middleman**:

1. The private server sends a request to the NAT Gateway
2. The NAT Gateway sends that request to the internet, using its own public Elastic IP as the return address
3. The internet sends the response back to the NAT Gateway's public IP
4. The NAT Gateway forwards the response back to the private server

The internet only ever sees the NAT Gateway's IP — it never knows the private server exists.

### One-way only — this is important

The NAT Gateway only allows **outbound-initiated connections**. The private server can reach out to the internet, but nothing on the internet can initiate a connection to the private server on its own.

An Internet Gateway, by contrast, allows both directions (inbound and outbound).

### Why must the NAT Gateway live in a PUBLIC subnet?

The NAT Gateway itself needs internet access to do its job. It gets that access through the public subnet's route to the Internet Gateway.

The flow is:
```
Private server → (private route table) → NAT Gateway in public subnet → (public route table) → Internet Gateway → Internet
```

If you put the NAT Gateway in a private subnet, it would have no path to the internet itself, so it could not forward anything.

### In this project

```
Name:     my-codeCreatedNATGW
Location: Public_Subnet_1
EIP:      my-codeCreatedNATGW-EIP
```

---

## 8. Security Groups

### What is a security group?

A security group is a **virtual firewall** that controls what network traffic is allowed in and out of an EC2 instance. Every instance must belong to at least one security group.

Security groups work with two lists of rules:
- **Inbound rules** — what traffic is allowed TO reach the instance
- **Outbound rules** — what traffic is allowed to LEAVE the instance

### How do rules work?

Each rule specifies:

| Field | Example | Meaning |
|---|---|---|
| Type | SSH | A label for the kind of traffic |
| Protocol | TCP | The network protocol |
| Port range | 22 | Which port(s) the rule applies to |
| Source/Destination | 0.0.0.0/0 | Where the traffic comes from (inbound) or goes to (outbound) |

`0.0.0.0/0` as a source means "from anywhere on the internet." For a learning project this is convenient, but in production you would restrict SSH to specific trusted IP addresses.

### Security groups are stateful

This is an important detail. "Stateful" means if you allow inbound traffic in on a port, the response is automatically allowed back out — you do not need a separate outbound rule for it. This is different from network ACLs (a more advanced topic) which are stateless.

### Default deny

Any traffic not explicitly allowed by a rule is **blocked by default**. You do not need to write "deny" rules — the absence of an allow rule is the deny.

### In this project

**Security group: `ec2_HeartBeat`** — applied to all three instances:

| Direction | Protocol | Port | Source | Purpose |
|---|---|---|---|---|
| Inbound | TCP | 22 | 0.0.0.0/0 | SSH access to manage instances |
| Inbound | TCP | 80 | 0.0.0.0/0 | HTTP access to the Heartbeat web dashboard |
| Outbound | All | All | 0.0.0.0/0 | Allow instances to reach the internet (git clone, dnf update, etc.) |

---

## 9. EC2 Instances

### What is an EC2 instance?

EC2 stands for **Elastic Compute Cloud**. An EC2 instance is a **virtual server** running in AWS. You choose the operating system, the hardware size, and which network to put it in — AWS runs it for you in one of their data centres.

### What is an instance type?

The instance type determines how much CPU, RAM, and network capacity the instance gets. The naming convention is:

```
t2.micro
│  └── size (nano, micro, small, medium, large, xlarge…)
└─── family (t = burstable general purpose, m = memory optimised, c = compute optimised…)
```

`t2.micro` is the smallest general-purpose instance. It has 1 vCPU and 1 GB RAM. It is in the AWS Free Tier for new accounts, which is why it is used in this learning project.

### What is an AMI?

AMI stands for **Amazon Machine Image**. It is a snapshot of an operating system and any pre-installed software. When you launch an EC2 instance, you choose an AMI — it is what gets installed on the instance.

This project uses **Amazon Linux 2023** — AWS's own Linux distribution. The user-data script uses `dnf` (the package manager for Amazon Linux 2023 and RHEL-based systems). Using a data source to look up the latest AMI ID automatically means the code never has a hardcoded AMI ID that expires.

### What is user data?

User data is a **shell script that runs automatically the first time an instance boots**. It is AWS's way of letting you customise an instance without having to log in and set it up manually.

In this project, the user-data script:
1. Updates the OS
2. Installs git, Python 3, and pip
3. Creates a `heartbeat_User` service account
4. Clones the Heartbeat Automation repository from GitHub
5. Installs Python dependencies
6. Installs and starts three systemd services (`heartbeat.service`, `heartbeat.timer`, `heartbeat-web.service`)

You can see the output of the user-data script after launch by SSHing in and running:
```bash
cat /var/log/user-data.log
```

### What is shutdown behaviour?

When you run `sudo shutdown now` or power off an instance from inside the OS, AWS can either:
- **Stop** the instance — it powers off but keeps the EBS (storage) disk and can be started again. You still pay for the storage.
- **Terminate** the instance — it is permanently deleted, including the disk. No further charges.

This project sets shutdown behaviour to **terminate** because the instances are disposable. If you need a new one, you re-run the Create script or re-apply Terraform. This prevents forgotten stopped instances quietly accumulating charges.

### In this project

| Instance | Subnet | Public IP source | Role |
|---|---|---|---|
| `Bastion_Host` | Public_Subnet_1 | Subnet auto-assign | Entry point into the private network |
| `Private_HeartBeat_1` | Private_Subnet_1 | Explicitly assigned at launch | Runs the Heartbeat app |
| `Private_HeartBeat_2` | Private_Subnet_1 | Explicitly assigned at launch | Runs the Heartbeat app |

---

## 10. Bastion Host (Jump Server)

### What is a bastion host?

A bastion host is a **single, hardened EC2 instance placed in a public subnet that acts as the only doorway into your private network**.

Without a bastion host, if you want to SSH into a private instance you would have to open SSH (port 22) to the internet on that private instance. That means every private instance in your network is a potential target.

With a bastion host:
1. Only the bastion host has SSH open to the internet
2. You SSH into the bastion first
3. From inside the bastion (which is already inside the VPC), you SSH to the private instance using its **private IP address**

This means only one machine faces the internet. If something gets compromised, the blast radius is limited. You also have one place to put your access logs and security controls.

### The connection flow

```
Your laptop
    │
    │  SSH (port 22) over the public internet
    ▼
Bastion_Host (public IP in Public_Subnet_1)
    │
    │  SSH (port 22) over the private VPC network
    ▼
Private_HeartBeat_1 or Private_HeartBeat_2 (private IP in Private_Subnet_1)
```

### How do you connect in practice?

```bash
# Step 1 — SSH into the bastion host using its public IP
ssh -i your-key.pem ec2-user@<BASTION_PUBLIC_IP>

# Step 2 — From the bastion, SSH to a private instance using its private IP
ssh -i your-key.pem ec2-user@<PRIVATE_INSTANCE_PRIVATE_IP>
```

A more advanced technique is **SSH agent forwarding** (`ssh -A`) which lets you use your local key from inside the bastion without copying the key file to the bastion. This is more secure.

### Why is the bastion in a PUBLIC subnet?

Because you need to reach it from the internet. A bastion in a private subnet would have no public IP and no internet route, so you could never connect to it from outside the VPC.

---

## 11. How Everything Connects — The Full Flow

Now that you know each piece, here is how they all work together. Follow the journey of a network packet.

### Scenario A — You SSH into the bastion host from your laptop

```
Your laptop
    │  SSH over the public internet to the bastion's public IP
    ▼
Internet Gateway (the front door)
    │
    ▼
Public_Subnet_1
    │  Security group allows port 22 inbound
    ▼
Bastion_Host (has a public IP from subnet auto-assign)
```

### Scenario B — You SSH from the bastion to a private instance

```
Bastion_Host (inside the VPC)
    │  SSH to private IP — stays inside VPC
    ▼
Route table: 10.0.0.0/16 → local (no gateway needed, it's internal)
    │
    ▼
Private_HeartBeat_1 (in Private_Subnet_1)
    │  Security group allows port 22 inbound
    ▼
You are in
```

### Scenario C — A private instance downloads packages during setup (user-data)

```
Private_HeartBeat_1 (no public IP from subnet, but has one assigned at launch)
    │
    ▼
Private Route Table: 0.0.0.0/0 → NAT Gateway
    │
    ▼
NAT Gateway (in Public_Subnet_1, has the Elastic IP)
    │
    ▼
Public Route Table: 0.0.0.0/0 → Internet Gateway
    │
    ▼
Internet Gateway → GitHub (git clone) / DNF repos (package updates)
```

The internet only sees the NAT Gateway's Elastic IP. The private instance is never exposed.

### Scenario D — Someone accesses the Heartbeat web dashboard

```
Browser on the internet
    │  HTTP port 80 to the bastion's public IP
    ▼
Internet Gateway
    │
    ▼
Public_Subnet_1
    │  Security group allows port 80 inbound
    ▼
Bastion_Host running heartbeat-web.service
```

---

## 12. Why Deletion Order Matters

AWS resources have **dependencies** — some resources rely on others to exist. If you try to delete a resource that something else still depends on, AWS will refuse and give you an error.

This is why the Delete script removes resources in reverse order from how they were created:

```
1. Terminate all EC2 instances + wait for terminated state
        (instances hold ENIs inside subnets — nothing can be deleted while an ENI exists)
2. Disassociate and delete the private route table
3. Delete NAT Gateway + wait for it to fully stop
        (must fully stop before the EIP can be released)
4. Release Elastic IP
        (must happen after NAT Gateway is gone)
5. Disassociate and delete the public route table
6. Detach Internet Gateway from VPC
        (must be detached before it can be deleted)
7. Delete Internet Gateway
8. Delete the security group
        (can only be deleted once no instance ENIs reference it)
9. Delete subnets
        (must be completely empty)
10. Delete VPC
        (must have no subnets, gateways, or route tables remaining)
```

Think of it like a tower of blocks — you built it from the bottom up, so you have to remove blocks from the top down or the whole thing falls over with errors.

---

## 13. Public IP vs Private IP vs Elastic IP — Summary

This trips up a lot of beginners. Here is a clear comparison:

| | Private IP | Public IP (auto-assigned) | Elastic IP |
|---|---|---|---|
| Who can reach it? | Only inside the VPC | Anyone on the internet | Anyone on the internet |
| Stays the same if instance stops? | Yes | **No** — changes on restart | **Yes** — permanent |
| Costs money? | No | No | Yes, if not attached to a running resource |
| Assigned how? | Automatically by AWS | Automatically (subnet setting) or explicitly at launch | You allocate it manually |
| Typical use | Internal VPC communication | Temporary public access for servers | NAT Gateways, anything needing a stable public IP |

---

## 14. Availability Zones — Why Use More Than One?

An **Availability Zone** (AZ) is a physically separate data centre within an AWS region. Each AZ has its own independent power supply, cooling, and networking.

`us-east-1` (Northern Virginia) has multiple AZs: `us-east-1a`, `us-east-1b`, `us-east-1c`, and so on.

### Why spread subnets across AZs?

If you put everything in one AZ and that data centre has a power outage, fire, or network problem — your entire application goes down.

By putting subnets in different AZs and running your servers across them, your application keeps working even if one AZ has a problem. This is called **high availability**.

### In this project

```
Public_Subnet_1   us-east-1a   ← bastion host and NAT Gateway live here
Private_Subnet_1  us-east-1a   ← both Heartbeat instances live here
Public_Subnet_2   us-east-1b   ← second public subnet for future use in a different AZ
```

Public_Subnet_2 is in `us-east-1b` so there is a public subnet available in a second AZ if you add a second bastion host or load balancer later.

---

## 15. The Terraform Perspective

When you write this infrastructure in Terraform, each AWS concept maps directly to a Terraform **resource block**:

| AWS concept | Terraform resource |
|---|---|
| VPC | `aws_vpc` |
| Subnet | `aws_subnet` |
| Internet Gateway | `aws_internet_gateway` |
| Elastic IP | `aws_eip` |
| NAT Gateway | `aws_nat_gateway` |
| Route Table | `aws_route_table` |
| Route Table Association | `aws_route_table_association` |
| Security Group | `aws_security_group` |
| EC2 Instance | `aws_instance` |
| AMI lookup | `data "aws_ami"` (a data source, not a resource — it reads, not creates) |

Terraform reads all these blocks, figures out which resources depend on which others (for example, the NAT Gateway needs the EIP and the subnet to exist first), and creates them in the correct order automatically. When you run `terraform destroy`, it does the same thing in reverse.

This is one of the main advantages of Terraform over writing bash scripts — you describe **what you want**, and Terraform figures out **how and in what order** to create or delete it.

---

## 16. Glossary

| Term | Plain English explanation |
|---|---|
| **VPC** | Your private, isolated network in AWS |
| **Subnet** | A section of your VPC for a specific purpose or location |
| **CIDR** | A way of writing a range of IP addresses (e.g. `10.0.1.0/24`) |
| **Internet Gateway** | The door between your VPC and the public internet |
| **NAT Gateway** | A middleman that lets private servers reach the internet without being reachable from it |
| **Elastic IP** | A fixed, permanent public IP address you own in your AWS account |
| **Route Table** | A list of rules telling network traffic where to go |
| **Route** | A single rule in a route table: "traffic going to X should go via Y" |
| **Route Table Association** | The link that connects a route table to a subnet |
| **Auto-assign public IPv4** | A subnet setting that automatically gives public IPs to new instances |
| **Availability Zone** | A physically separate data centre within an AWS region |
| **Public subnet** | A subnet connected to the internet via an Internet Gateway |
| **Private subnet** | A subnet that can reach the internet via NAT but cannot be reached from the internet by default |
| **0.0.0.0/0** | Means "any IP address" — used as the catch-all destination in route tables |
| **local route** | The automatic route in every VPC that allows internal communication between subnets |
| **Security group** | A virtual firewall that controls inbound and outbound traffic for an EC2 instance |
| **EC2 instance** | A virtual server running in AWS |
| **AMI** | Amazon Machine Image — the operating system snapshot used to launch an instance |
| **Instance type** | The hardware size of an EC2 instance (e.g. `t2.micro` = 1 vCPU, 1 GB RAM) |
| **User data** | A shell script that runs automatically the first time an instance boots |
| **Shutdown behaviour** | What happens when the OS shuts down: stop (keeps the instance, costs money) or terminate (deletes it permanently) |
| **Bastion host** | A hardened public instance used as the single entry point to reach private instances via SSH |
| **Jump server** | Another name for a bastion host |
| **SSH** | Secure Shell — the protocol used to remotely log in and manage Linux servers |
| **Terraform** | An infrastructure-as-code tool — you write what you want, it creates it |
| **AWS CLI** | A command-line tool for interacting with AWS directly from the terminal |
| **IaC** | Infrastructure as Code — managing cloud resources through code files rather than clicking in a console |
| **ENI** | Elastic Network Interface — the virtual network card attached to an EC2 instance; must be removed before subnets or security groups can be deleted |

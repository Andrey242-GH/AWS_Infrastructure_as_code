# AWS Networking Concepts — A Beginner's Guide

This document explains every networking concept and resource used in this project, from scratch. It assumes you have never built cloud infrastructure before. Each section explains **what the thing is**, **why it exists**, and **how it connects to everything else**.

---

## The Big Picture — What Are We Building?

Before diving into individual pieces, here is the full picture of what this project creates and why.

Imagine you are setting up a small office building:

- The **building** is your **VPC** — it is your private space, separated from everyone else
- The **rooms** inside the building are your **subnets** — different areas for different purposes
- The **front door** to the outside world is the **Internet Gateway**
- The **security desk** that lets people in the front rooms but keeps the back rooms hidden is the **NAT Gateway**
- The **directory on the wall** telling people which room to go to is the **Route Table**
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
Some resources should be reachable from the internet (like a web server). Others should never be reachable from the internet (like a database). By putting them in separate subnets, you can apply different rules to each.

**2. Availability zones**
AWS data centres are grouped into **Availability Zones** (AZs). An AZ is essentially a separate physical building with its own power, cooling, and networking. Each subnet can only live in one AZ. By creating subnets in different AZs, your application stays online even if one data centre has a problem.

### Public vs Private subnets

This is one of the most important concepts in cloud networking:

| | Public subnet | Private subnet |
|---|---|---|
| Directly reachable from the internet? | Yes | No |
| Can reach the internet? | Yes, directly via IGW | Yes, indirectly via NAT Gateway |
| Typical use | Web servers, load balancers, NAT Gateway | Databases, application servers, backend services |

The label "public" or "private" is not a built-in AWS setting on the subnet itself. A subnet becomes public when you:
1. Connect it to a route table that has a route to an Internet Gateway
2. Enable auto-assign public IPv4

A subnet becomes private when it routes internet traffic through a NAT Gateway instead.

### What is auto-assign public IPv4?

By default, when you launch a server (EC2 instance) in a subnet, it only gets a **private IP address** — one that only works inside the VPC. Nobody on the internet can reach it.

When you enable **auto-assign public IPv4** on a subnet, every instance launched there automatically also gets a **public IP address** — one that works on the real internet. This is what makes web servers reachable.

Private subnets do NOT have this enabled. Their servers only get private IPs, which means the internet cannot reach them directly. That is the whole point.

### In this project

```
Public_Subnet_1   10.0.1.0/24   us-east-1a   auto-assign public IPv4: YES
Public_Subnet_2   10.0.2.0/24   us-east-1b   auto-assign public IPv4: YES
Private_Subnet_1  10.0.10.0/24  us-east-1a   auto-assign public IPv4: NO
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

- **Public subnets**: send internet traffic → Internet Gateway (direct connection)
- **Private subnets**: send internet traffic → NAT Gateway (indirect, one-way connection)

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

Here is the problem it solves: your private database server needs to download a software update from the internet. But it has no public IP address, so the internet does not know how to reply to it. The NAT Gateway solves this by acting as a **middleman**:

1. The private server sends a request to the NAT Gateway
2. The NAT Gateway sends that request to the internet, using its own public Elastic IP as the return address
3. The internet sends the response back to the NAT Gateway's public IP
4. The NAT Gateway forwards the response back to the private server

The internet only ever sees the NAT Gateway's IP — it never knows the private server exists.

### One-way only — this is important

The NAT Gateway only allows **outbound-initiated connections**. The private server can reach out to the internet, but nothing on the internet can initiate a connection to the private server. This is the security benefit.

An Internet Gateway, by contrast, allows both directions (inbound and outbound).

### Why must the NAT Gateway live in a PUBLIC subnet?

The NAT Gateway itself needs internet access to do its job — it needs to forward traffic to and from the internet. It gets that access through the public subnet's route to the Internet Gateway.

The flow is:
```
Private server → (private route table) → NAT Gateway in public subnet → (public route table) → Internet Gateway → Internet
```

If you put the NAT Gateway in a private subnet, it would have no path to the internet itself, so it could not forward anything.

### Why does it need its own Elastic IP?

The NAT Gateway needs a stable, fixed public IP so the internet knows where to send responses. This is the Elastic IP you allocate separately and attach to it.

### In this project

```
Name:     my-codeCreatedNATGW
Location: Public_Subnet_1
EIP:      my-codeCreatedNATGW-EIP
```

---

## 8. How Everything Connects — The Full Flow

Now that you know each piece, here is how they all work together. Follow the journey of a network packet.

### Scenario A — Someone visits your web server (public subnet)

```
Internet user
    │
    ▼
Internet Gateway (the front door)
    │   Route table says: local traffic stays local, everything from outside comes here
    ▼
Public_Subnet_1 or Public_Subnet_2
    │   Server has a public IP (auto-assign was enabled on the subnet)
    ▼
Your web server (EC2 instance)
```

The response travels back the same path in reverse.

### Scenario B — Your private database downloads an update

```
Private_Subnet_1 database server (no public IP)
    │
    ▼
Private Route Table: 0.0.0.0/0 → NAT Gateway
    │
    ▼
NAT Gateway (sitting in Public_Subnet_1, has a public EIP)
    │
    ▼
Public Route Table: 0.0.0.0/0 → Internet Gateway
    │
    ▼
Internet Gateway
    │
    ▼
Internet (software update server)
```

The response comes back through the same chain. The internet only sees the NAT Gateway's EIP. The database server is never exposed.

### Scenario C — Your web server talks to your database

```
Web server in Public_Subnet_1
    │
    ▼
Route table: 10.0.0.0/16 → local
    │   (destination is inside the VPC, so no gateway is needed)
    ▼
Database in Private_Subnet_1
```

Traffic between subnets within the same VPC travels directly using the `local` route. No gateway involved.

---

## 9. Why Deletion Order Matters

AWS resources have **dependencies** — some resources rely on others to exist. If you try to delete a resource that something else still depends on, AWS will refuse and give you an error.

This is why the Delete script removes resources in reverse order from how they were created:

```
1. Disassociate private route table from subnets
        (must happen before deleting the route table)
2. Delete private route table
3. Delete NAT Gateway + wait for it to fully stop
        (must fully stop before the EIP can be released)
4. Release Elastic IP
        (must happen after NAT Gateway is gone)
5. Disassociate public route table from subnets
6. Delete public route table
7. Detach Internet Gateway from VPC
        (must be detached before it can be deleted)
8. Delete Internet Gateway
9. Delete subnets
        (must be empty — no running instances, no NAT Gateways)
10. Delete VPC
        (must have no subnets, gateways, or route tables remaining)
```

Think of it like a tower of blocks — you built it from the bottom up, so you have to remove blocks from the top down or the whole thing falls over (errors out).

---

## 10. Public IP vs Private IP vs Elastic IP — Summary

This trips up a lot of beginners. Here is a clear comparison:

| | Private IP | Public IP (auto-assigned) | Elastic IP |
|---|---|---|---|
| Who can reach it? | Only inside the VPC | Anyone on the internet | Anyone on the internet |
| Stays the same if instance stops? | Yes | **No** — changes on restart | **Yes** — permanent |
| Costs money? | No | No | Yes, if not attached to a running resource |
| Assigned how? | Automatically by AWS | Automatically if subnet has auto-assign enabled | You allocate it manually |
| Typical use | Internal VPC communication | Temporary public access for servers | NAT Gateways, anything needing a stable public IP |

---

## 11. Availability Zones — Why Use More Than One?

An **Availability Zone** (AZ) is a physically separate data centre within an AWS region. Each AZ has its own independent power supply, cooling, and networking.

`us-east-1` (Northern Virginia) has multiple AZs: `us-east-1a`, `us-east-1b`, `us-east-1c`, and so on.

### Why spread subnets across AZs?

If you put everything in one AZ and that data centre has a power outage, fire, or network problem — your entire application goes down.

By putting subnets in different AZs and running your servers across them, your application keeps working even if one AZ has a problem. This is called **high availability**.

### In this project

```
Public_Subnet_1   us-east-1a
Private_Subnet_1  us-east-1a
Public_Subnet_2   us-east-1b   ← different AZ from the others
```

Public_Subnet_2 is in `us-east-1b` so that if `us-east-1a` goes down, there is still a public subnet available in another AZ for web traffic.

---

## 12. The Terraform Perspective

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

Terraform reads all these blocks, figures out which resources depend on which others (for example, the NAT Gateway needs the EIP and the subnet to exist first), and creates them in the correct order automatically. When you run `terraform destroy`, it does the same thing in reverse.

This is one of the main advantages of Terraform over writing bash scripts — you describe **what you want**, and Terraform figures out **how and in what order** to create or delete it.

---

## 13. Glossary

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
| **Private subnet** | A subnet that can reach the internet via NAT but cannot be reached from the internet |
| **0.0.0.0/0** | Means "any IP address" — used as the catch-all destination in route tables |
| **local route** | The automatic route in every VPC that allows internal communication between subnets |
| **Terraform** | An infrastructure-as-code tool — you write what you want, it creates it |
| **AWS CLI** | A command-line tool for interacting with AWS directly from the terminal |
| **EC2 instance** | A virtual server running in AWS |
| **IaC** | Infrastructure as Code — managing cloud resources through code files rather than clicking in a console |

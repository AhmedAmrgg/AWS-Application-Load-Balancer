# 🚀 AWS Infrastructure with Terraform — VPC, ALB, EC2, and Security Groups

This project provisions a complete AWS infrastructure using Terraform.
It includes a Virtual Private Cloud (VPC) with public, private, and database subnets, an Application Load Balancer (ALB), EC2 instances, and properly configured Security Groups.
This setup is designed to simulate a real-world environment for deploying web applications with load balancing and network segmentation.

## 🧱 Project Architecture

The infrastructure includes:

- VPC
Public, Private, and Database subnets across multiple Availability Zones.
NAT Gateway for outbound internet access from private subnets.
DNS support and hostname resolution enabled.

- Security Groups
Bastion SG (Public access via SSH)
Private SG (Access limited to VPC CIDR)
Load Balancer SG (HTTP access from internet)

- EC2 Instances
Public instance (bastion host)
Private instances (application servers) created via loop\
- Elastic IP
Allocated to the public bastion host

- Application Load Balancer
HTTP listener on port 80
Health check path /app1/index.html
Targets EC2 instances in private subnets

```
🏗️ Architecture Diagram
                   +-------------------------+
                   |      Internet Gateway    |
                   +-----------+-------------+
                               |
                      +--------v--------+
                      |   Public Subnet  |
                      |  (Bastion Host)  |
                      +--------+--------+
                               |
                               |
                +--------------v------------------+
                |      Application Load Balancer  |
                +--------------+------------------+
                               |
                +--------------v------------------+
                |          Private Subnets        |
                |     (EC2 App Instances)         |
                +--------------+------------------+
                               |
                      +--------v--------+
                      |  Database Subnet |
                      |  (Future RDS)    |
                      +------------------+
```
## ⚙️ Terraform Modules Used
Module	Source	Purpose
- VPC	terraform-aws-modules/vpc/aws	Creates the full VPC structure
- Security Group	terraform-aws-modules/security-group/aws	Defines access control
- EC2 Instance	terraform-aws-modules/ec2-instance/aws	Provisions EC2 instances
- ALB	terraform-aws-modules/alb/aws	Creates Application Load Balancer

#🧩 Project Structure
├── main.tf
├── variables.tf
├── outputs.tf
├── app1-install.sh
├── terraform.tfvars
└── README.md

🔧 How to Use
1️⃣ Prerequisites
- AWS account and credentials configured (aws configure)
- Terraform installed (>= 1.3.0)
- SSH key pairs created in AWS (e.g., alb and k8s)

2️⃣ Initialize Terraform
```
terraform init
```
3️⃣ Validate Configuration
```
terraform validate
```
4️⃣ Plan the Deployment
```
terraform plan
```
5️⃣ Apply the Configuration
```
terraform apply -auto-approve
```
6️⃣ Destroy Resources (when finished)
```
terraform destroy -auto-approve
```
## 🧠 Key Learnings from This Project
- How to use Terraform modules to create reusable and clean infrastructure code.
- Building a highly available network using VPC and subnets.
- Configuring security groups to control traffic at multiple layers.
- Attaching EC2 instances to an Application Load Balancer.
- Using Elastic IPs for stable public access.
- Managing infrastructure through IaC (Infrastructure as Code) best practices.

## 🧩 Next Steps (Future Enhancements)
- Add RDS database to the database subnet
- Integrate Auto Scaling Group for EC2 instances
- Deploy via GitHub Actions (CI/CD)
- Add CloudWatch or Prometheus monitoring
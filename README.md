# EKS Cluster with Karpenter - Multi-Environment Setup

Production-ready Amazon EKS cluster deployment using Terraform with ARM64/Graviton nodes and Karpenter for dynamic node provisioning.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Environment Configuration](#environment-configuration)
- [Deployment Instructions](#deployment-instructions)
- [Post-Deployment](#post-deployment)
- [Creating Kubernetes Namespaces](#creating-kubernetes-namespaces)
- [Cleanup](#cleanup)
- [Troubleshooting](#troubleshooting)

## 🏗️ Architecture Overview

This project deploys a fully-managed Amazon EKS cluster with the following characteristics:

- **EKS Version**: 1.28
- **Node Architecture**: ARM64 (Graviton processors)
- **Node Management**: Karpenter for dynamic, cost-optimized autoscaling
- **Network**: Private subnets only (production-ready)
- **Security**: Existing VPC, security groups, and SSH keys
- **Environments**: dev, pre-prod, prod with separate configurations

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud                           │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    Existing VPC                       │  │
│  │  ┌──────────────────────────────────────────────────┐ │  │
│  │  │         Private Subnets (3 AZs)                  │ │  │
│  │  │  ┌────────────────────────────────────────────┐  │ │  │
│  │  │  │         EKS Control Plane                  │  │ │  │
│  │  │  └────────────────────────────────────────────┘  │ │  │
│  │  │  ┌────────────────────────────────────────────┐  │ │  │
│  │  │  │  Karpenter Controller Nodes (Managed)      │  │ │  │
│  │  │  │  • t4g.medium/large/c7g.large (ARM64)      │  │ │  │
│  │  │  │  • Min: 2-3 nodes (per env)                │  │ │  │
│  │  │  └────────────────────────────────────────────┘  │ │  │
│  │  │  ┌────────────────────────────────────────────┐  │ │  │
│  │  │  │  Karpenter-Managed Workload Nodes          │  │ │  │
│  │  │  │  • Auto-scaled based on workload           │  │ │  │
│  │  │  │  • ARM64 instances (t4g, c7g, m7g, r7g)    │  │ │  │
│  │  │  │  • On-demand & Spot (dev/pre-prod)         │  │ │  │
│  │  │  └────────────────────────────────────────────┘  │ │  │
│  │  └──────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## ✨ Features

- ✅ **Infrastructure as Code**: 100% Terraform-managed infrastructure
- ✅ **Graviton ARM64 Nodes**: Cost-effective and high-performance
- ✅ **Karpenter Integration**: Dynamic node provisioning and scaling
- ✅ **Multi-Environment**: Separate dev, pre-prod, and prod environments
- ✅ **Security**: Private subnets, existing security groups, SSH keys
- ✅ **High Availability**: Multi-AZ deployment
- ✅ **Spot Instance Support**: Cost optimization (non-prod environments)
- ✅ **Interrupt Handling**: Automatic handling of spot interruptions

## 📦 Prerequisites

### Required Tools

Install the following tools on your local machine:

```bash
# AWS CLI (v2)
aws --version  # Should be >= 2.0

# Terraform
terraform version  # Should be >= 1.3

# kubectl
kubectl version --client  # Should be >= 1.28

# Helm (for Karpenter installation)
helm version  # Should be >= 3.0
```

### AWS Prerequisites

Before running Terraform, ensure you have:

1. **VPC with Private Subnets**
   - Minimum 3 private subnets across different AZs
   - Properly tagged for discovery

2. **Security Group**
   - Named "OfficeIPs" (or your preferred name)
   - Contains your office/admin IP ranges

3. **SSH Key Pair**
   - Created in EC2 for potential node access

4. **S3 Bucket**
   - For Terraform state storage
   - Enable versioning and encryption

5. **IAM Permissions**
   - EKS cluster creation
   - EC2 instance management
   - IAM role/policy management

### Verify Prerequisites

Run this verification script:

```bash
# Check AWS CLI and default region
aws sts get-caller-identity
aws configure get region

# Verify VPC exists (replace with your VPC name)
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=main-vpc"

# Verify security group exists (replace with your security group name)
aws ec2 describe-security-groups --filters "Name=group-name,Values=OfficeIPs"

# Verify SSH key exists (replace with your key name)
aws ec2 describe-key-pairs --key-names your-key-name

# Check if S3 bucket for state exists (replace with your bucket name)
aws s3 ls s3://your-terraform-state-bucket
```

## 🚀 Quick Start

### Step 1: Identify Your AWS Resources

Before running the code, gather the following information from your AWS account:

1. **VPC ID**: Find your VPC ID from the AWS Console or CLI
2. **Subnet IDs**: Identify 3 private subnet IDs in different availability zones
3. **Security Group**: Note the name/ID of your security group
4. **SSH Key Name**: Note the name of your EC2 key pair
5. **S3 Bucket**: Name of your Terraform state bucket

### Step 2: Tag Your AWS Resources

Your VPC and subnets must be properly tagged for Terraform to discover them.

**Tag the VPC:**
```bash
# Replace with your actual VPC ID
VPC_ID="vpc-xxxxxxxxxxxxxxxxx"
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=main-vpc
```

**Tag Private Subnets:**
```bash
# Replace with your actual subnet IDs (3 subnets in different AZs)
SUBNET_IDS="subnet-xxxxx subnet-yyyyy subnet-zzzzz"

for SUBNET_ID in $SUBNET_IDS; do
  aws ec2 create-tags --resources $SUBNET_ID --tags \
    Key=Type,Value=private \
    Key=Name,Value=private-subnet-${SUBNET_ID: -4}
done
```

### Step 3: Create Required AWS Resources (If Not Already Present)

**Create Security Group (if not exists):**
```bash
# Replace VPC_ID with your actual VPC ID
aws ec2 create-security-group \
  --group-name OfficeIPs \
  --description "Office IP whitelist for EKS nodes" \
  --vpc-id vpc-xxxxxxxxxxxxxxxxx

# Add your IP (replace with your actual IP)
aws ec2 authorize-security-group-ingress \
  --group-name OfficeIPs \
  --protocol tcp \
  --port 22 \
  --cidr YOUR_IP_ADDRESS/32
```

**Create SSH Key Pair (if not exists):**
```bash
# Replace with your preferred key name
aws ec2 create-key-pair \
  --key-name your-key-name \
  --query 'KeyMaterial' \
  --output text > your-key-name.pem

chmod 400 your-key-name.pem
```

**Create S3 Bucket for Terraform State:**
```bash
# Replace with your preferred bucket name (must be globally unique)
BUCKET_NAME="your-terraform-state-bucket-name"
REGION="us-east-1"  # Replace with your region

aws s3 mb s3://$BUCKET_NAME --region $REGION

aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

### Step 4: Clone and Configure

```bash
# Clone the repository
git clone https://github.com/yourusername/eks-terraform-project.git
cd eks-terraform-project

# Choose an environment to deploy (start with dev)
cd environments/dev

# Edit terraform.tfvars with your actual values
# Update the following variables:
# - vpc_name = "your-vpc-name"
# - ssh_key_name = "your-key-name"
# - region = "your-aws-region"
# - cluster_name = "your-cluster-name"
# - Any other environment-specific values

# Edit main.tf and update the S3 backend configuration
# Update:
# - bucket = "your-terraform-state-bucket"
# - region = "your-aws-region"
# - key = "path/to/your/state/file"
```

### Step 5: Initialize and Deploy

```bash
# Initialize Terraform (downloads providers and modules)
terraform init

# Validate configuration
terraform validate

# Review the execution plan
terraform plan

# Apply the configuration (takes ~15-20 minutes)
terraform apply

# Confirm by typing 'yes' when prompted

# Note the outputs for kubectl configuration
```

### Step 6: Configure kubectl and Access the Cluster

```bash
# Update kubeconfig (replace with your region and cluster name)
aws eks update-kubeconfig \
  --region your-region \
  --name your-cluster-name

# Verify connection
kubectl get nodes

# Check Karpenter is running
kubectl get pods -n karpenter
kubectl get deployment -n karpenter
```

## 📁 Project Structure

```
eks-terraform-project/
├── environments/
│   ├── dev/
│   │   ├── main.tf              # Main configuration for dev
│   │   ├── variables.tf         # Variable definitions
│   │   ├── terraform.tfvars     # Variable values (not in git)
│   │   └── outputs.tf           # Output values
│   ├── pre-prod/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── outputs.tf
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       └── outputs.tf
├── modules/
│   ├── networking/
│   │   ├── data.tf              # Data sources for VPC discovery
│   │   ├── variables.tf         # Module variables
│   │   └── outputs.tf           # Module outputs
│   ├── eks/
│   │   ├── main.tf              # EKS cluster configuration
│   │   ├── variables.tf         # Module variables
│   │   ├── outputs.tf           # Module outputs
│   │   └── versions.tf          # Provider versions
│   └── karpenter/
│       ├── main.tf              # Karpenter installation
│       ├── variables.tf         # Module variables
│       ├── outputs.tf           # Module outputs
│       └── versions.tf          # Provider versions
├── .gitignore
└── README.md
```

## ⚙️ Environment Configuration

Each environment has different configurations optimized for its purpose:

| Setting | Dev | Pre-Prod | Prod |
|---------|-----|----------|------|
| Cluster Name | eks-dev-cluster | eks-pre-prod-cluster | eks-prod-cluster |
| Public Access | Yes | No | No |
| Controller Nodes | 2 x t4g.medium | 3 x t4g.large | 3 x c7g.large |
| Capacity Type | On-demand | On-demand + Spot | On-demand |
| CPU Limit | 50 cores | 75 cores | 200 cores |
| Memory Limit | 100Gi | 150Gi | 400Gi |
| Instance Families | t4g, c7g, m7g | t4g, c7g, m7g | c7g, m7g, r7g |

**Note**: Adjust these values in your `terraform.tfvars` file based on your requirements.

## 📝 Deployment Instructions

### Deploy Development Environment

```bash
cd environments/dev

# Initialize Terraform
terraform init

# Create execution plan
terraform plan -out=tfplan

# Apply the plan
terraform apply tfplan

# Configure kubectl (replace with your values)
aws eks update-kubeconfig \
  --region your-region \
  --name eks-dev-cluster
```

### Deploy Pre-Production Environment

```bash
cd environments/pre-prod

terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Configure kubectl (replace with your values)
aws eks update-kubeconfig \
  --region your-region \
  --name eks-pre-prod-cluster
```

### Deploy Production Environment

```bash
cd environments/prod

terraform init
terraform plan -out=tfplan

# Extra verification before production deploy
terraform plan -detailed-exitcode

terraform apply tfplan

# Configure kubectl (replace with your values)
aws eks update-kubeconfig \
  --region your-region \
  --name eks-prod-cluster
```

## 🎯 Post-Deployment

### Verify Cluster Health

```bash
# Check nodes
kubectl get nodes

# Check Karpenter
kubectl get pods -n karpenter
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter

# Check Karpenter resources
kubectl get nodepool
kubectl get ec2nodeclass
```

### Test Karpenter Autoscaling

Deploy a test workload to verify Karpenter scales nodes:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate
spec:
  replicas: 0
  selector:
    matchLabels:
      app: inflate
  template:
    metadata:
      labels:
        app: inflate
    spec:
      containers:
      - name: inflate
        image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
        resources:
          requests:
            cpu: 1
EOF

# Scale up to trigger Karpenter
kubectl scale deployment inflate --replicas=10

# Watch nodes being created
kubectl get nodes -w

# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f

# Scale down
kubectl delete deployment inflate
```

## 🏷️ Creating Kubernetes Namespaces

After cluster deployment, create namespaces for application workloads:

### Option 1: Using kubectl

```bash
# Create namespaces for each environment
kubectl create namespace dev
kubectl create namespace pre-prod
kubectl create namespace prod

# Verify
kubectl get namespaces
```

### Option 2: Using YAML Manifests

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: dev
  labels:
    environment: dev
    managed-by: kubectl
---
apiVersion: v1
kind: Namespace
metadata:
  name: pre-prod
  labels:
    environment: pre-prod
    managed-by: kubectl
---
apiVersion: v1
kind: Namespace
metadata:
  name: prod
  labels:
    environment: prod
    managed-by: kubectl
EOF
```

### Set Default Namespace (Optional)

```bash
# For dev environment
kubectl config set-context --current --namespace=dev

# Verify
kubectl config view --minify | grep namespace
```

### Namespace Resource Quotas (Recommended)

```bash
# Example: Set resource quotas for dev namespace
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"
EOF
```

## 🧹 Cleanup

To destroy the infrastructure:

```bash
# From the environment directory
cd environments/dev

# Destroy
terraform destroy

# Or with auto-approve (be careful!)
terraform destroy -auto-approve
```

**Important**: Ensure all Karpenter-provisioned nodes are terminated before destroying:

```bash
# Delete all deployments first
kubectl delete deployments --all -A

# Wait for Karpenter to scale down
kubectl get nodes -w

# Then destroy infrastructure
terraform destroy
```


## 📊 Monitoring and Observabilit

### View Karpenter Metrics

```bash
# Port-forward to Karpenter metrics
kubectl port-forward -n karpenter svc/karpenter 8080:8080

# Access metrics at http://localhost:8080/metrics
```

```

## 🔒 Security Best Practices

- ✅ All production clusters use private subnets only
- ✅ No public API endpoint access in production
- ✅ Security groups restrict access to authorized IPs
- ✅ SSH keys required for node access
- ✅ IAM roles for service accounts (IRSA) enabled
- ✅ Encryption enabled for all data at rest
- ✅ Network policies should be implemented for pod-to-pod communication
- ✅ Regular security audits and updates
- ✅ Least privilege IAM policies

---

## 🎯 Summary of Steps to Run the Code

1. **Install Prerequisites**: AWS CLI, Terraform, kubectl, and Helm
2. **Gather AWS Information**: VPC ID, subnet IDs, security group, SSH key name
3. **Tag Resources**: Tag your VPC and subnets appropriately
4. **Create S3 Bucket**: For Terraform state storage
5. **Clone Repository**: Get the code on your local machine
6. **Configure Variables**: Edit `terraform.tfvars` with your values
7. **Update Backend**: Modify S3 backend configuration in `main.tf`
8. **Initialize Terraform**: Run `terraform init`
9. **Plan Deployment**: Run `terraform plan` to review changes
10. **Apply Configuration**: Run `terraform apply` to create resources
11. **Configure kubectl**: Update kubeconfig to access the cluster
12. **Verify Deployment**: Check nodes and Karpenter status
13. **Test Autoscaling**: Deploy test workload to verify Karpenter
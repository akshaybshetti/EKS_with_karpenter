#!/bin/bash

# EKS Deployment Helper Script
# This script assists with deploying the EKS cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}EKS Cluster Deployment Helper${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command_exists aws; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

if ! command_exists terraform; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    exit 1
fi

if ! command_exists kubectl; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites installed${NC}"
echo ""

# Check AWS credentials
echo -e "${YELLOW}Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    exit 1
fi

AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
echo -e "${GREEN}✓ AWS Account: ${AWS_ACCOUNT}${NC}"
echo -e "${GREEN}✓ AWS Region: ${AWS_REGION}${NC}"
echo ""

# Select environment
echo -e "${YELLOW}Select environment to deploy:${NC}"
echo "1) dev"
echo "2) pre-prod"
echo "3) prod"
read -p "Enter choice [1-3]: " env_choice

case $env_choice in
    1)
        ENV="dev"
        ;;
    2)
        ENV="pre-prod"
        ;;
    3)
        ENV="prod"
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}Selected environment: ${ENV}${NC}"
echo ""

# Change to environment directory
ENV_DIR="environments/${ENV}"
if [ ! -d "$ENV_DIR" ]; then
    echo -e "${RED}Error: Environment directory not found: ${ENV_DIR}${NC}"
    exit 1
fi

cd "$ENV_DIR"

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}Error: terraform.tfvars not found${NC}"
    echo -e "${YELLOW}Please create terraform.tfvars from terraform.tfvars.example${NC}"
    exit 1
fi

echo -e "${YELLOW}Deployment Steps:${NC}"
echo "1. Initialize Terraform"
echo "2. Plan infrastructure"
echo "3. Apply infrastructure"
echo "4. Configure kubectl"
echo "5. Create Kubernetes namespaces"
echo ""
read -p "Continue? (yes/no): " continue_choice

if [ "$continue_choice" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

# Step 1: Terraform Init
echo ""
echo -e "${YELLOW}Step 1: Initializing Terraform...${NC}"
terraform init

# Step 2: Terraform Plan
echo ""
echo -e "${YELLOW}Step 2: Planning infrastructure...${NC}"
terraform plan -out=tfplan

echo ""
read -p "Review the plan above. Continue with apply? (yes/no): " apply_choice

if [ "$apply_choice" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

# Step 3: Terraform Apply
echo ""
echo -e "${YELLOW}Step 3: Applying infrastructure (this takes ~15 minutes)...${NC}"
terraform apply tfplan

# Step 4: Configure kubectl
echo ""
echo -e "${YELLOW}Step 4: Configuring kubectl...${NC}"
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION=$(terraform output -raw region)

aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

echo -e "${GREEN}✓ kubectl configured for cluster: ${CLUSTER_NAME}${NC}"

# Step 5: Verify cluster
echo ""
echo -e "${YELLOW}Verifying cluster...${NC}"
kubectl get nodes
kubectl get pods -n karpenter

# Step 6: Create namespaces
echo ""
echo -e "${YELLOW}Step 5: Creating Kubernetes namespaces...${NC}"
read -p "Create namespaces now? (yes/no): " ns_choice

if [ "$ns_choice" = "yes" ]; then
    cd ../..
    kubectl apply -f kubernetes-namespaces.yaml
    echo -e "${GREEN}✓ Namespaces created${NC}"
fi

# Success
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Cluster Name: ${CLUSTER_NAME}"
echo -e "Region: ${REGION}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Verify cluster: kubectl get nodes"
echo "2. Check Karpenter: kubectl get pods -n karpenter"
echo "3. Deploy workloads to namespaces: dev, pre-prod, prod"
echo ""
echo -e "${YELLOW}To destroy the cluster later:${NC}"
echo "cd environments/${ENV}"
echo "terraform destroy"
echo ""

# AWS Resource Tagging Guide

Before deploying the Terraform code, you must tag your existing AWS resources so Terraform can discover them.

## Your Current Resources (from screenshots)

**VPC:**
- VPC ID: `vpc-0837f80df815d47c3`
- CIDR: `172.31.0.0/16`
- State: Available

**Subnets (6 total):**
- `subnet-046649f59dd3df024` - CIDR: 172.31.48.0/20
- `subnet-0Oebbf495935fc5c5` - CIDR: 172.31.0.0/20
- `subnet-0da781ddc8e76c620` - CIDR: 172.31.80.0/20
- `subnet-071f7bc2cfb608f7c` - CIDR: 172.31.64.0/20
- `subnet-03c075c60752c550c` - CIDR: 172.31.32.0/20
- `subnet-041537573c9360913` - CIDR: 172.31.16.0/20

## Step 1: Identify Private Subnets

First, determine which subnets are "private" (no direct internet access):

```bash
# Check each subnet's route table
for SUBNET_ID in subnet-046649f59dd3df024 subnet-0Oebbf495935fc5c5 subnet-0da781ddc8e76c620 subnet-071f7bc2cfb608f7c subnet-03c075c60752c550c subnet-041537573c9360913; do
    echo "Checking $SUBNET_ID"
    aws ec2 describe-route-tables \
        --filters "Name=association.subnet-id,Values=$SUBNET_ID" \
        --query 'RouteTables[*].Routes[?GatewayId!=`local`].{Destination:DestinationCidrBlock,Gateway:GatewayId}' \
        --output table
    echo ""
done
```

**Private subnets** have routes pointing to:
- NAT Gateway (`nat-xxxxx`)
- No internet route at all
- Only local routes

**Public subnets** have routes pointing to:
- Internet Gateway (`igw-xxxxx`)

## Step 2: Tag the VPC

```bash
# Tag your VPC
aws ec2 create-tags \
    --resources vpc-0837f80df815d47c3 \
    --tags \
        Key=Name,Value=main-vpc \
        Key=Environment,Value=shared \
        Key=ManagedBy,Value=manual \
        Key=Project,Value=eks-cluster

# Verify tags
aws ec2 describe-vpcs --vpc-ids vpc-0837f80df815d47c3 --query 'Vpcs[*].Tags'
```

## Step 3: Tag Private Subnets

### Option A: Tag Specific Subnets (Recommended)

Choose 3 subnets in different availability zones as private subnets:

```bash
# Example: Tag first 3 subnets as private
aws ec2 create-tags \
    --resources subnet-046649f59dd3df024 \
    --tags \
        Key=Name,Value=private-subnet-1 \
        Key=Type,Value=private \
        Key=Environment,Value=shared \
        Key=kubernetes.io/role/internal-elb,Value=1

aws ec2 create-tags \
    --resources subnet-0Oebbf495935fc5c5 \
    --tags \
        Key=Name,Value=private-subnet-2 \
        Key=Type,Value=private \
        Key=Environment,Value=shared \
        Key=kubernetes.io/role/internal-elb,Value=1

aws ec2 create-tags \
    --resources subnet-0da781ddc8e76c620 \
    --tags \
        Key=Name,Value=private-subnet-3 \
        Key=Type,Value=private \
        Key=Environment,Value=shared \
        Key=kubernetes.io/role/internal-elb,Value=1
```

### Option B: Tag All Subnets as Private

If all your subnets should be private:

```bash
# Define all subnet IDs
SUBNET_IDS=(
    "subnet-046649f59dd3df024"
    "subnet-0Oebbf495935fc5c5"
    "subnet-0da781ddc8e76c620"
    "subnet-071f7bc2cfb608f7c"
    "subnet-03c075c60752c550c"
    "subnet-041537573c9360913"
)

# Tag each subnet
COUNTER=1
for SUBNET_ID in "${SUBNET_IDS[@]}"; do
    aws ec2 create-tags \
        --resources "$SUBNET_ID" \
        --tags \
            Key=Name,Value=private-subnet-$COUNTER \
            Key=Type,Value=private \
            Key=Environment,Value=shared \
            Key=kubernetes.io/role/internal-elb,Value=1
    
    echo "Tagged $SUBNET_ID as private-subnet-$COUNTER"
    ((COUNTER++))
done
```

### Verify Subnet Tags

```bash
# Verify all private subnets are tagged correctly
aws ec2 describe-subnets \
    --filters "Name=tag:Type,Values=private" \
    --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock,Tags[?Key==`Name`].Value | [0]]' \
    --output table
```

## Step 4: Create/Verify Security Group

```bash
# Check if OfficeIPs security group exists
aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=OfficeIPs" \
    --query 'SecurityGroups[*].[GroupId,GroupName,Description]' \
    --output table

# If it doesn't exist, create it:
SG_ID=$(aws ec2 create-security-group \
    --group-name OfficeIPs \
    --description "Security group for office IP access to EKS nodes" \
    --vpc-id vpc-0837f80df815d47c3 \
    --output text)

echo "Created security group: $SG_ID"

# Add your office IP (replace with your actual IP)
YOUR_IP="1.2.3.4"  # Replace with your IP
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 22 \
    --cidr "$YOUR_IP/32" \
    --tag-specifications "ResourceType=security-group-rule,Tags=[{Key=Name,Value=office-ssh-access}]"

# For kubectl access (optional - only for dev)
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 443 \
    --cidr "$YOUR_IP/32"
```

## Step 5: Create/Verify SSH Key Pair

```bash
# Check if key pair exists
aws ec2 describe-key-pairs --key-names eks-node-key

# If it doesn't exist, create it:
aws ec2 create-key-pair \
    --key-name eks-node-key \
    --query 'KeyMaterial' \
    --output text > eks-node-key.pem

chmod 400 eks-node-key.pem

echo "SSH key saved to eks-node-key.pem"
echo "IMPORTANT: Store this key securely!"
```

## Step 6: Verify All Resources

Run this verification script:

```bash
#!/bin/bash

echo "=== Verification ==="
echo ""

echo "1. VPC:"
aws ec2 describe-vpcs \
    --vpc-ids vpc-0837f80df815d47c3 \
    --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value | [0]]' \
    --output table

echo ""
echo "2. Private Subnets:"
aws ec2 describe-subnets \
    --filters "Name=tag:Type,Values=private" "Name=vpc-id,Values=vpc-0837f80df815d47c3" \
    --query 'Subnets[*].[SubnetId,AvailabilityZone,Tags[?Key==`Name`].Value | [0]]' \
    --output table

echo ""
echo "3. Security Group:"
aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=OfficeIPs" \
    --query 'SecurityGroups[*].[GroupId,GroupName,VpcId]' \
    --output table

echo ""
echo "4. SSH Key:"
aws ec2 describe-key-pairs \
    --key-names eks-node-key \
    --query 'KeyPairs[*].[KeyName,KeyPairId]' \
    --output table

echo ""
echo "=== Verification Complete ==="
```

## Step 7: Update Terraform Configuration

After tagging, update your `terraform.tfvars`:

```hcl
# environments/dev/terraform.tfvars

aws_region = "us-east-1"

cluster_name    = "eks-dev-cluster"
cluster_version = "1.28"

# These should match the tags you created
vpc_name_tag                = "main-vpc"
office_security_group_name  = "OfficeIPs"
ssh_key_name                = "eks-node-key"

# Rest of configuration...
```

## Quick Tag Script

Save this as `tag-resources.sh` and run it:

```bash
#!/bin/bash

# Your resource IDs
VPC_ID="vpc-0837f80df815d47c3"
PRIVATE_SUBNETS=(
    "subnet-046649f59dd3df024"
    "subnet-0Oebbf495935fc5c5"
    "subnet-0da781ddc8e76c620"
)

# Tag VPC
echo "Tagging VPC..."
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=main-vpc

# Tag Subnets
echo "Tagging subnets..."
COUNTER=1
for SUBNET in "${PRIVATE_SUBNETS[@]}"; do
    aws ec2 create-tags --resources $SUBNET --tags \
        Key=Name,Value=private-subnet-$COUNTER \
        Key=Type,Value=private
    ((COUNTER++))
done

echo "Tagging complete!"
```

## Troubleshooting

### Issue: Subnets not found by Terraform

Check if tags are correct:
```bash
aws ec2 describe-subnets --filters "Name=tag:Type,Values=private"
```

### Issue: Wrong subnets selected

Ensure only private subnets are tagged with `Type=private`

### Issue: Security group not found

Verify the security group exists in the correct VPC:
```bash
aws ec2 describe-security-groups --filters "Name=group-name,Values=OfficeIPs" "Name=vpc-id,Values=vpc-0837f80df815d47c3"
```

## Next Steps

Once tagging is complete:
1. Review your `terraform.tfvars` file
2. Run `terraform init`
3. Run `terraform plan` to verify Terraform can find all resources
4. Proceed with `terraform apply`

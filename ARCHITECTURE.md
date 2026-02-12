# EKS Architecture Diagram

This document contains architecture diagrams for the EKS deployment.

## Infrastructure Architecture

```mermaid
graph TB
    subgraph AWS["AWS Cloud"]
        subgraph VPC["VPC: 172.31.0.0/16"]
            subgraph AZ1["Availability Zone 1"]
                PS1["Private Subnet 1<br/>172.31.48.0/20"]
            end
            subgraph AZ2["Availability Zone 2"]
                PS2["Private Subnet 2<br/>172.31.0.0/20"]
            end
            subgraph AZ3["Availability Zone 3"]
                PS3["Private Subnet 3<br/>172.31.80.0/20"]
            end
            
            subgraph EKS["EKS Control Plane"]
                API["API Server"]
                ETCD["etcd"]
                CM["Controller Manager"]
                SCH["Scheduler"]
            end
            
            subgraph Nodes["Worker Nodes"]
                subgraph MNG["Managed Node Group<br/>(Karpenter Controllers)"]
                    N1["t4g.medium<br/>ARM64"]
                    N2["t4g.medium<br/>ARM64"]
                end
                
                subgraph KN["Karpenter-Managed Nodes"]
                    KN1["Dynamic Nodes<br/>t4g/c7g/m7g<br/>ARM64"]
                end
            end
            
            SG["Security Group<br/>OfficeIPs"]
        end
        
        S3["S3 Bucket<br/>Terraform State"]
        SQS["SQS Queue<br/>Spot Interruption"]
    end
    
    User["Admin/Developer"]
    
    User -->|kubectl/SSH| EKS
    EKS -->|Manages| MNG
    MNG -->|Runs| KARP["Karpenter Controller"]
    KARP -->|Provisions| KN
    KARP -->|Monitors| SQS
    
    PS1 -.->|Hosts| N1
    PS2 -.->|Hosts| N2
    PS3 -.->|Hosts| KN1
    
    SG -.->|Protects| Nodes
    
    style EKS fill:#FF9900
    style VPC fill:#4A90E2
    style MNG fill:#7CB342
    style KN fill:#FFA726
```

## Karpenter Workflow

```mermaid
sequenceDiagram
    participant Pod as New Pod
    participant K8s as Kubernetes Scheduler
    participant Karp as Karpenter Controller
    participant AWS as AWS EC2
    participant Node as New Node
    
    Pod->>K8s: Schedule pod
    K8s->>K8s: No capacity available
    K8s->>Karp: Unschedulable pod event
    Karp->>Karp: Evaluate NodePool & EC2NodeClass
    Karp->>AWS: Launch EC2 instance (ARM64)
    AWS->>Node: Instance created
    Node->>K8s: Register with cluster
    K8s->>Node: Schedule pod
    Node->>Pod: Pod running
    
    Note over Karp,AWS: Karpenter monitors for<br/>spot interruptions via SQS
```

## Multi-Environment Deployment

```mermaid
graph LR
    subgraph Repo["Git Repository"]
        MOD["Modules<br/>• networking<br/>• eks<br/>• karpenter"]
    end
    
    subgraph Env["Environments"]
        DEV["Dev<br/>• Public Access<br/>• 2 nodes<br/>• t4g.medium"]
        PRE["Pre-Prod<br/>• Private<br/>• 3 nodes<br/>• t4g.large"]
        PROD["Prod<br/>• Private<br/>• 3 nodes<br/>• c7g.large"]
    end
    
    subgraph AWS["AWS Account"]
        DEV_CLUSTER["eks-dev-cluster"]
        PRE_CLUSTER["eks-pre-prod-cluster"]
        PROD_CLUSTER["eks-prod-cluster"]
    end
    
    MOD -->|Reused by| DEV
    MOD -->|Reused by| PRE
    MOD -->|Reused by| PROD
    
    DEV -->|terraform apply| DEV_CLUSTER
    PRE -->|terraform apply| PRE_CLUSTER
    PROD -->|terraform apply| PROD_CLUSTER
    
    style DEV fill:#81C784
    style PRE fill:#FFA726
    style PROD fill:#EF5350
```

## Namespace Organization

```mermaid
graph TB
    subgraph Cluster["EKS Cluster"]
        subgraph KS["kube-system"]
            CORE["CoreDNS<br/>kube-proxy<br/>aws-node"]
        end
        
        subgraph KARP["karpenter"]
            KC["Karpenter<br/>Controller"]
        end
        
        subgraph DEV["dev namespace"]
            DEV_APP["Development<br/>Applications"]
        end
        
        subgraph PRE["pre-prod namespace"]
            PRE_APP["Pre-Production<br/>Applications"]
        end
        
        subgraph PROD["prod namespace"]
            PROD_APP["Production<br/>Applications"]
        end
    end
    
    style KS fill:#42A5F5
    style KARP fill:#66BB6A
    style DEV fill:#81C784
    style PRE fill:#FFA726
    style PROD fill:#EF5350
```

## Security Architecture

```mermaid
graph TB
    subgraph Internet["Internet"]
        USER["Developer"]
    end
    
    subgraph AWS["AWS Cloud"]
        subgraph VPC["VPC"]
            subgraph Private["Private Subnets"]
                EKS_API["EKS API Endpoint"]
                NODES["Worker Nodes"]
            end
            
            SG1["Security Group<br/>OfficeIPs"]
            SG2["Cluster SG"]
            SG3["Node SG"]
        end
        
        IAM["IAM Roles"]
        IRSA["IRSA<br/>(IAM Roles for<br/>Service Accounts)"]
    end
    
    USER -->|VPN/Bastion| Private
    SG1 -->|SSH:22| NODES
    SG2 -->|443| EKS_API
    SG3 -->|All traffic| NODES
    
    IAM -->|Assumes| IRSA
    IRSA -->|Karpenter<br/>Controller| NODES
    
    style SG1 fill:#FFA726
    style SG2 fill:#42A5F5
    style SG3 fill:#66BB6A
    style IAM fill:#AB47BC
```

## Data Flow

```mermaid
graph LR
    subgraph Client["Client"]
        DEV_TEAM["Developers"]
        OPS_TEAM["DevOps"]
    end
    
    subgraph Control["Control Plane"]
        TF["Terraform"]
        KUBECTL["kubectl"]
    end
    
    subgraph State["State Management"]
        S3["S3 Backend"]
    end
    
    subgraph Cluster["EKS Cluster"]
        API["API Server"]
        KARP_CTRL["Karpenter"]
        WORKLOAD["Workloads"]
    end
    
    subgraph Data["Data Layer"]
        EBS["EBS Volumes"]
        LOGS["CloudWatch Logs"]
    end
    
    DEV_TEAM -->|Deploy Apps| KUBECTL
    OPS_TEAM -->|Manage Infra| TF
    
    TF <-->|State| S3
    TF -->|Provisions| Cluster
    KUBECTL -->|Commands| API
    
    API -->|Schedules| WORKLOAD
    KARP_CTRL -->|Scales| WORKLOAD
    
    WORKLOAD -->|Stores| EBS
    Cluster -->|Logs| LOGS
    
    style TF fill:#7B42BC
    style KUBECTL fill:#326CE5
    style KARP_CTRL fill:#FF9900
```

## Resource Tagging Strategy

```mermaid
graph TB
    subgraph Resources["AWS Resources"]
        VPC["VPC<br/>Tag: Name=main-vpc"]
        SUB["Subnets<br/>Tag: Type=private"]
        SG["Security Group<br/>Tag: Name=OfficeIPs"]
    end
    
    subgraph TF["Terraform Data Sources"]
        VPC_DS["data.aws_vpc.main"]
        SUB_DS["data.aws_subnets.private"]
        SG_DS["data.aws_security_group.office_ips"]
    end
    
    subgraph Discovery["Dynamic Discovery"]
        LOOKUP["Tag-based Lookup"]
    end
    
    VPC -->|Tags| LOOKUP
    SUB -->|Tags| LOOKUP
    SG -->|Tags| LOOKUP
    
    LOOKUP -->|Queries| VPC_DS
    LOOKUP -->|Queries| SUB_DS
    LOOKUP -->|Queries| SG_DS
    
    VPC_DS -->|Provides IDs| TF
    SUB_DS -->|Provides IDs| TF
    SG_DS -->|Provides IDs| TF
    
    style LOOKUP fill:#4CAF50
    style TF fill:#7B42BC
```

# Frontend Deployment Runbook (What Next)

Use this after the EKS cluster is provisioned by Terraform.

## 1) One-time platform setup

1. Create app namespaces:
   ```bash
   kubectl create namespace frontend-dev
   kubectl create namespace frontend-pre-prod
   kubectl create namespace frontend-prod
   ```
2. Apply RBAC template (edit group name first if needed):
   ```bash
   kubectl apply -f k8s/rbac/frontend-team-rbac.yaml
   ```
3. Create ECR repository:
   ```bash
   aws ecr create-repository --repository-name frontend-app
   ```
4. Ensure your GitHub OIDC role (`AWS_GITHUB_ACTIONS_ROLE_ARN`) can:
   - Push images to ECR
   - Run `eks:DescribeCluster`
   - Access cluster through `aws eks update-kubeconfig`

## 2) Frontend repo prerequisites

Your frontend repo should have:

- `frontend/` directory with Dockerfile
- This workflow file copied to `.github/workflows/frontend-cicd.yaml`
- Kubernetes manifest copied to `k8s/apps/frontend/frontend-app.yaml`

## 3) Required GitHub secret

Create repository secret:

- `AWS_GITHUB_ACTIONS_ROLE_ARN`: IAM role for GitHub Actions OIDC

> This workflow intentionally does **not** require a static kubeconfig secret.

## 4) Deploy flow

### Automatic (dev)
- Push to `main` -> workflow builds image, pushes to ECR, and deploys to `frontend-dev`.

### Manual (pre-prod/prod)
- In GitHub Actions, run workflow manually (`workflow_dispatch`) and select:
  - `pre-prod` or `prod`

## 5) Verify deployment

```bash
kubectl -n frontend-dev get deploy,svc,ingress
kubectl -n frontend-dev get pods -l app=frontend
kubectl -n frontend-dev rollout status deployment/frontend
```

## 6) Rollback quickly

```bash
kubectl -n frontend-dev rollout undo deployment/frontend
```

## 7) Common issues

- **Image pull error**: check ECR permissions on worker role / repository policy.
- **Ingress not created**: ensure AWS Load Balancer Controller is installed.
- **Cannot connect to cluster**: run workflow from network path that can reach EKS endpoint (private endpoint environments).

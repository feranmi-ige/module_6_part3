# CI/CD + GitOps setup (GHCR + Argo CD-ready)

This repo is structured as an **application repository** that builds container images and (optionally) updates a separate **GitOps repository** that Argo CD watches.
# Module_6_Part3 — Production-Ready Kubernetes Manifests
## What you get from all
- Services: `backend` (Flask), `transactions` (Node), `studentportfolio` (Nginx static), `syncer` (Mongo sync).
- Two independent MongoDBs: `mongo-backend` and `mongo-transactions` (on 4.4.18).
- A `transactions-sync` deployment copies user-embedded transactions from backend DB to a flat `transactions` collection in the transactions DB every 60s.
- Production-leaning K8s manifests under `k8s/`, with images pointing at GHCR placeholders:  
  `ghcr.io/OWNER/REPO-<service>:latest`  
  The GitHub workflow bumps these to `:${GITHUB_SHA}` on every push to the gitops repository created

## Secrets to create (Repository → Settings → Secrets and variables → Actions)
- **CR_PAT**: a Classic Personal Access Token with `write:packages` (to push to GHCR). 
This is an alternative but not 
  Alternatively, make GHCR packages public and use `${{ github.token }}` (advanced).
- **GITOPS_PAT**: a PAT with `repo` scope to push to the GitOps repo.
- **GITOPS_REPO** (Actions secret _value_ like `myorg/myapp-gitops`): optional.  
  If set, the workflow clones that repo and commits the image tag bumps there.  
  If **not** set, it bumps *this repo's* `k8s/` folder...

> Make sure the **packages visibility** in GHCR is set so your cluster can pull.  
> For private images on a new cluster, create a Kubernetes `imagePullSecret` in the target namespace and add it to your Deployments.

## Branch protection
The workflow triggers on `push` to `main`. Protect the branch as needed.

## Argo CD (example)
Point an Argo CD Application to your **GitOps repo** (or this repo if you didn't split):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: m6p2
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<OWNER>/<GITOPS-REPO>.git
    targetRevision: main
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Local testing (Minikube)
Running locally on Minikube:
- Either keep using the provided `apply_minikube_dockerenv.sh` (builds to Minikube’s Docker daemon), or
- `docker build` and `docker push` to GHCR, then `kubectl apply -f k8s/`.



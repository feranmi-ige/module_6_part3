#!/usr/bin/env bash
set -euo pipefail

minikube start --driver=docker
minikube status

chmod +x apply_minikube_dockerenv.sh
# Force builds into Minikube's Docker daemon (Docker driver)
eval "$(minikube -p minikube docker-env)"

IMAGES=("backend:latest" "transactions:latest" "studentportfolio:latest")

for img in "${IMAGES[@]}"; do
  name="${img%%:*}"
  echo ">> docker build -t ${img} ./${name}"
  docker build -t "${img}" "./${name}"
done

echo "==> Verify images inside the node's Docker:"
minikube ssh -- docker images | egrep 'backend|transactions|studentportfolio' || true

echo "==> Apply manifests"
kubectl apply -f k8s/

echo "==> Restart deployments to pick up local images"
kubectl rollout restart deploy backend transactions studentportfolio

echo
echo "Open the app:"
echo "  minikube service nginx"
echo "or http://$(minikube ip):30080"

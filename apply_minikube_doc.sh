#!/usr/bin/env bash
# Robust bash settings:
# -e : exit on error
# -u : treat unset vars as errors
# -o pipefail : any failure in a pipeline fails the pipeline
set -euo pipefail

############################################
# Configuration (override via env if needed)
############################################
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"   # Minikube profile name
NAMESPACE="${NAMESPACE:-default}"                  # Kubernetes namespace to use
IMAGES=("backend:latest" "transactions:latest" "studentportfolio:latest")  # image:tag
DEPLOYMENTS=("backend" "transactions" "studentportfolio")                  # k8s Deployment names
K8S_DIR="${K8S_DIR:-k8s}"                           # path to k8s manifests
OPEN_SERVICE="${OPEN_SERVICE:-nginx}"               # service to open in browser (expects a NodePort)

############################################
# Helper functions for consistent output
############################################
info()  { printf "\n\033[1;34m[INFO]\033[0m %s\n"  "$*"; }
warn()  { printf "\n\033[1;33m[WARN]\033[0m %s\n"  "$*"; }
error() { printf "\n\033[1;31m[ERR ]\033[0m %s\n"  "$*" >&2; }

require_cmd() {
  # Verify a required command exists on PATH
  command -v "$1" >/dev/null 2>&1 || { error "Missing required command: $1"; exit 1; }
}

############################################
# Preflight checks
############################################
info "Checking required CLIs are installed"
require_cmd minikube
require_cmd kubectl
require_cmd docker
require_cmd grep
require_cmd awk



############################################
# Start (or ensure) Minikube using Docker driver
############################################
info "Starting Minikube (profile: ${MINIKUBE_PROFILE}) with Docker driver"
# 'minikube start' is idempotent; it will reuse an existing cluster/profile
minikube start --driver=docker -p "${MINIKUBE_PROFILE}"

info "Minikube status"
minikube status -p "${MINIKUBE_PROFILE}"

############################################
# Build images directly inside Minikube's Docker daemon
# This avoids pushing to a remote registry and ensures Pods can pull local images.
############################################
info "Pointing Docker CLI to Minikube's Docker daemon"
eval "$(minikube -p "${MINIKUBE_PROFILE}" docker-env)"

# Build each local image from its matching folder name (e.g., backend -> ./backend)
# Skips missing folders with a warning instead of failing the entire script.
for img in "${IMAGES[@]}"; do
  name="${img%%:*}"           # e.g., "backend" from "backend:latest"
  context="./${name}"
  if [[ -d "${context}" ]]; then
    info "Building image ${img} from ${context}"
    docker build -t "${img}" "${context}"
  else
    warn "Build context not found: ${context} (skipping ${img})"
  fi
done

# Show images as seen from the node (sanity check)
info "Verifying images inside the node's Docker daemon"
# Use grep -E (egrep is deprecated) and allow empty result without failing
minikube ssh -p "${MINIKUBE_PROFILE}" -- docker images | grep -E 'backend|transactions|studentportfolio' || true

############################################
# Apply Kubernetes manifests
############################################
if [[ -d "${K8S_DIR}" ]]; then
  info "Applying Kubernetes manifests from ${K8S_DIR}"
  kubectl apply -n "${NAMESPACE}" -f "${K8S_DIR}"
else
  error "Kubernetes manifests directory not found: ${K8S_DIR}"
  exit 1
fi

############################################
# Restart deployments to pick up freshly built images
# (use explicit resource type and namespace; skip any that don't exist)
############################################
info "Restarting deployments to pick up local images (if present)"
for d in "${DEPLOYMENTS[@]}"; do
  if kubectl get deployment "${d}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    kubectl rollout restart deployment "${d}" -n "${NAMESPACE}"
  else
    warn "Deployment not found (skipping restart): ${d} (ns=${NAMESPACE})"
  fi
done

############################################
# Wait for deployments to become available
############################################
info "Waiting for deployments to become ready"
for d in "${DEPLOYMENTS[@]}"; do
  if kubectl get deployment "${d}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    kubectl rollout status deployment "${d}" -n "${NAMESPACE}" --timeout=180s
  fi
done

echo
echo "Open the app: everything has been deployed"
echo " Command to open the app =  minikube service nginx"
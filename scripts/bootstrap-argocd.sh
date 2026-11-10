#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "🎭 Mask & Maker — K3s ArgoCD GitOps Bootstrap"
echo "=================================================================="

export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

echo "[1/5] Creating 'argocd' and 'maskandmaker' namespaces..."
sudo kubectl create namespace argocd --dry-run=client -o yaml | sudo kubectl apply -f -
sudo kubectl create namespace maskandmaker --dry-run=client -o yaml | sudo kubectl apply -f -

echo "[2/5] Installing ArgoCD in 'argocd' namespace (server-side apply to handle large CRDs)..."
sudo kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "[3/5] Waiting for ArgoCD Server to become ready..."
sudo kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

echo "[4/5] Applying Mask & Maker ArgoCD AppProject & Root App-of-Apps..."
REPO_RAW="https://raw.githubusercontent.com/Kushan20070126/gitops-mask_and_maker/main"
if [ -f "./argocd/project.yaml" ] && [ -f "./argocd/root-app.yaml" ]; then
  sudo kubectl apply -f ./argocd/project.yaml
  sudo kubectl apply -f ./argocd/root-app.yaml
else
  sudo kubectl apply -f "${REPO_RAW}/argocd/project.yaml"
  sudo kubectl apply -f "${REPO_RAW}/argocd/root-app.yaml"
fi

echo "[5/5] Fetching initial ArgoCD admin password..."
ARGOCD_PASS=""
for i in {1..30}; do
  ARGOCD_PASS=$(sudo kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || true)
  if [ -n "$ARGOCD_PASS" ]; then
    break
  fi
  sleep 2
done
ARGOCD_PASS="${ARGOCD_PASS:-pending}"

echo "=================================================================="
echo "✅ ArgoCD GitOps Bootstrap Complete!"
echo "------------------------------------------------------------------"
echo "👤 ArgoCD Username : admin"
echo "🔑 ArgoCD Password : ${ARGOCD_PASS}"
echo "------------------------------------------------------------------"
echo "Check sync status:"
echo "  sudo kubectl get applications -n argocd"
echo "  sudo kubectl get pods -n maskandmaker"
echo "=================================================================="

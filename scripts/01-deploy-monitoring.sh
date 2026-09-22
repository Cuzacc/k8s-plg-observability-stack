#!/usr/bin/env bash
# ==============================================================================
# Automated Deployment Script for PLG Stack (Prometheus, Loki, Grafana)
# ==============================================================================

set -euo pipefail

NAMESPACE="monitoring"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "[INFO] [1/5] Initializing '${NAMESPACE}' namespace..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "[INFO] [2/5] Adding and updating Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

echo "[INFO] [3/5] Deploying Kube-Prometheus-Stack (Prometheus, Alertmanager, Node-Exporter)..."
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace "${NAMESPACE}" \
  -f "${ROOT_DIR}/helm/values/prometheus-stack-values.yaml" \
  --wait --timeout 10m

echo "[INFO] [4/5] Deploying Loki-Stack (Loki and Promtail DaemonSet)..."
helm upgrade --install loki grafana/loki-stack \
  --namespace "${NAMESPACE}" \
  -f "${ROOT_DIR}/helm/values/loki-values.yaml" \
  --wait --timeout 5m

echo "[INFO] [5/5] Applying custom Prometheus and Loki alerting rules..."
kubectl apply -f "${ROOT_DIR}/alerts/prometheus-rules.yaml"

echo "=========================================================================="
echo "[SUCCESS] PLG Observability Stack successfully deployed to namespace: ${NAMESPACE}"
echo "[INFO] Check status with: kubectl get pods,svc -n ${NAMESPACE}"
echo "=========================================================================="

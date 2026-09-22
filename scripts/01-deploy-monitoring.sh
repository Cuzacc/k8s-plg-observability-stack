#!/usr/bin/env bash
# ==============================================================================
# Enterprise Automated Deployment Script for PLG Stack (Prometheus, Loki, Grafana)
# ==============================================================================

set -euo pipefail

NAMESPACE="monitoring"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "🚀 [1/5] Initializing 'monitoring' Namespace..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "📦 [2/5] Adding & Updating Helm Repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

echo "⚙️ [3/5] Deploying Kube-Prometheus-Stack (Prometheus, Alertmanager, Node-Exporter)..."
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace "${NAMESPACE}" \
  -f "${ROOT_DIR}/helm/values/prometheus-stack-values.yaml" \
  --wait --timeout 10m

echo "📜 [4/5] Deploying Loki-Stack (Loki + Promtail DaemonSet)..."
helm upgrade --install loki grafana/loki-stack \
  --namespace "${NAMESPACE}" \
  -f "${ROOT_DIR}/helm/values/loki-values.yaml" \
  --wait --timeout 5m

echo "🚨 [5/5] Applying Custom Prometheus & Loki Alerting Rules..."
kubectl apply -f "${ROOT_DIR}/alerts/prometheus-rules.yaml"

echo "✅ =========================================================================="
echo "✅ PLG Observability Stack successfully deployed to namespace: ${NAMESPACE}"
echo "✅ Check status with: kubectl get pods,svc -n ${NAMESPACE}"
echo "✅ =========================================================================="

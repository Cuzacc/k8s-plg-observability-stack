#!/usr/bin/env bash
# ==============================================================================
# Teardown & Resource Cleanup Script
# ==============================================================================

set -euo pipefail

NAMESPACE="monitoring"

echo "⚠️ Tearing down PLG Observability Stack..."
helm uninstall prometheus -n "${NAMESPACE}" || true
helm uninstall loki -n "${NAMESPACE}" || true
kubectl delete -f alerts/prometheus-rules.yaml --ignore-not-found=true
kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true

echo "✅ All monitoring resources cleanly removed."

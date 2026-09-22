#!/usr/bin/env bash
# ==============================================================================
# Synthetic Alert Triggering & Verification Script
# ==============================================================================

set -euo pipefail

APP_URL="${1:-http://localhost:80}"

echo "=========================================================================="
echo "Alert Verification Suite for Kubernetes PLG Stack"
echo "Target Application URL: ${APP_URL}"
echo "=========================================================================="

show_menu() {
    echo ""
    echo "Select an Alert Verification Scenario:"
    echo "  1) [Scenario 1] Trigger High CPU Utilization Alert (>80%)"
    echo "  2) [Scenario 2] Trigger High HTTP 404 Error Spike Alert (Loki LogQL)"
    echo "  3) [Scenario 3] Trigger Pod CrashLoopBackOff Alert (Prometheus Counter)"
    echo "  4) Run All Tests in Sequence"
    echo "  q) Quit"
    echo ""
}

test_cpu_stress() {
    echo "[INFO] [Scenario 1] Generating concurrent synthetic traffic to stress CPU..."
    if command -v hey &> /dev/null; then
        hey -z 3m -c 250 -q 50 "${APP_URL}/"
    else
        echo "[WARN] 'hey' tool not found. Falling back to background curl requests..."
        for i in {1..50}; do
            while true; do curl -s "${APP_URL}/" > /dev/null; done &
        done
        sleep 180
        kill $(jobs -p) || true
    fi
    echo "[SUCCESS] Scenario 1 completed. Check Telegram for HighNodeCPUUtilization alert."
}

test_http_404() {
    echo "[INFO] [Scenario 2] Injecting 50 HTTP 404 invalid requests into Loki..."
    for i in {1..50}; do
        curl -s -o /dev/null "${APP_URL}/api/v1/invalid-endpoint-${i}" || true
        sleep 0.2
    done
    echo "[SUCCESS] Scenario 2 completed. Check Telegram for HighHTTP404RateSpike alert."
}

test_pod_crashloop() {
    echo "[INFO] [Scenario 3] Deploying faulty pod to trigger CrashLoopBackOff..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-crash-pod
  namespace: app
  labels:
    app: crash-test
spec:
  restartPolicy: Always
  containers:
    - name: crash-container
      image: busybox:1.36
      command: ["/bin/sh", "-c", "echo 'Simulating fatal error' && exit 1"]
EOF
    echo "[INFO] Waiting 60s for restart cycles to accumulate..."
    sleep 60
    echo "[INFO] Cleaning up faulty pod..."
    kubectl delete pod test-crash-pod -n app --ignore-not-found=true
    echo "[SUCCESS] Scenario 3 completed. Check Telegram for PodCrashLooping alert."
}

if [ "${2:-}" == "--all" ]; then
    test_cpu_stress
    test_http_404
    test_pod_crashloop
    exit 0
fi

show_menu
read -rp "Enter choice [1-4, q]: " choice

case "${choice}" in
    1) test_cpu_stress ;;
    2) test_http_404 ;;
    3) test_pod_crashloop ;;
    4)
        test_cpu_stress
        test_http_404
        test_pod_crashloop
        ;;
    q|Q) exit 0 ;;
    *) echo "[ERROR] Invalid choice." ; exit 1 ;;
esac

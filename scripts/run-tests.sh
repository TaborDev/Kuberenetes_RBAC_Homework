#!/usr/bin/env zsh
# Run RBAC tests from the homework manifests and save outputs to test-outputs/
set -u

# Quick pre-flight: ensure kubectl can talk to a cluster. Fail fast with a helpful message if not.
# Use `kubectl cluster-info` for compatibility across kubectl versions.
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "ERROR: kubectl cannot connect to the Kubernetes API server (cluster-info failed)."
  echo "Check that a cluster is running and your kubeconfig/context is correct."
  echo
  echo "Helpful checks and commands to run locally:"
  echo
  echo "  kubectl config current-context"
  echo "  kubectl cluster-info" 
  echo "  kubectl version --client" 
  echo "  minikube status     # if using minikube"
  echo "  kind get clusters   # if using kind"
  echo
  echo "If you use minikube, start it with:"
  echo "  minikube start"
  echo "If you use kind, create a cluster with:"
  echo "  kind create cluster"
  echo "If using a cloud cluster, ensure your kubeconfig is set to the correct context with:"
  echo "  kubectl config use-context <context-name>"
  exit 1
fi

OUTDIR="$(pwd)/test-outputs"
mkdir -p "$OUTDIR"

# Consolidated output files (one per Part)
PART1="$OUTDIR/part1.txt"
PART2="$OUTDIR/part2.txt"
PART3="$OUTDIR/part3.txt"
PART4="$OUTDIR/part4.txt"
PART5="$OUTDIR/part5.txt"
SUMMARY="$OUTDIR/summary.txt"

# Clear previous outputs
> "$PART1"
> "$PART2"
> "$PART3"
> "$PART4"
> "$PART5"
> "$SUMMARY"

echof() { echo "==== $1 ====" | tee -a "$SUMMARY"; }

echof "Part 1: Default service account - list and describe"
echo "==== Part 1: Default service account - list and describe ====" >> "$PART1"
kubectl get sa -n default | tee -a "$PART1"
echo "" >> "$PART1"
kubectl describe sa default -n default | tee -a "$PART1"
echo "" >> "$PART1"

echof "Part 1: Create test pod using default SA"
echo "==== Part 1: Create test pod using default SA ====" >> "$PART1"
kubectl apply -f "$(pwd)/yaml/part1-test-pod-default-sa.yaml" | tee -a "$PART1"
kubectl wait --for=condition=Ready pod/test-pod-default-sa -n default --timeout=60s 2>&1 | tee -a "$PART1" || true
echo "" >> "$PART1"

echof "Part 1: Inside pod: kubectl get pods (expected: Forbidden)"
echo "==== Part 1: Inside pod: kubectl get pods (expected: Forbidden) ====" >> "$PART1"
kubectl exec -n default test-pod-default-sa -- kubectl get pods 2>&1 | tee -a "$PART1" || true
echo "" >> "$PART1"

echof "Cleanup Part 1 pod"
echo "==== Cleanup Part 1 pod ====" >> "$PART1"
kubectl delete pod test-pod-default-sa -n default --ignore-not-found | tee -a "$PART1" "$SUMMARY"
echo "" >> "$PART1"

echof "Part 2: Monitoring namespace resources"
echo "==== Part 2: Monitoring namespace resources ====" >> "$PART2"
kubectl apply -f "$(pwd)/yaml/monitoring-namespace.yaml" | tee -a "$PART2"
kubectl apply -f "$(pwd)/yaml/monitoring-serviceaccount.yaml" | tee -a "$PART2"
kubectl apply -f "$(pwd)/yaml/monitoring-role.yaml" | tee -a "$PART2"
kubectl apply -f "$(pwd)/yaml/monitoring-rolebinding.yaml" | tee -a "$PART2"
kubectl apply -f "$(pwd)/yaml/monitoring-test-pod.yaml" | tee -a "$PART2"
kubectl wait --for=condition=Ready pod/monitoring-test-pod -n monitoring --timeout=60s 2>&1 | tee -a "$PART2" || true
echo "" >> "$PART2"

echof "Part 2: Inside monitoring test pod: list pods and deployments (expected: allowed)"
echo "==== Part 2: Inside monitoring test pod: list pods and deployments (expected: allowed) ====" >> "$PART2"
kubectl exec -n monitoring monitoring-test-pod -- kubectl get pods 2>&1 | tee -a "$PART2" || true
echo "" >> "$PART2"
kubectl exec -n monitoring monitoring-test-pod -- kubectl get deployments 2>&1 | tee -a "$PART2" || true
echo "" >> "$PART2"

echof "Part 2: Attempt to delete a pod as monitoring-reader (expected: Forbidden)"
echo "==== Part 2: Attempt to delete a pod as monitoring-reader (expected: Forbidden) ====" >> "$PART2"
kubectl exec -n monitoring monitoring-test-pod -- kubectl delete pod monitoring-test-pod 2>&1 | tee -a "$PART2" || true
echo "" >> "$PART2"

echof "Cleanup Part 2 resources"
echo "==== Cleanup Part 2 resources ====" >> "$PART2"
kubectl delete pod monitoring-test-pod -n monitoring --ignore-not-found | tee -a "$PART2" "$SUMMARY"
echo "" >> "$PART2"

echof "Part 3: Log collector cluster-wide read"
echo "==== Part 3: Log collector cluster-wide read ====" >> "$PART3"
kubectl apply -f "$(pwd)/yaml/log-collector-sa.yaml" | tee -a "$PART3"
kubectl apply -f "$(pwd)/yaml/log-reader-clusterrole.yaml" | tee -a "$PART3"
kubectl apply -f "$(pwd)/yaml/log-collector-clusterrolebinding.yaml" | tee -a "$PART3"
kubectl apply -f "$(pwd)/yaml/log-collector-test-pod.yaml" | tee -a "$PART3"
kubectl wait --for=condition=Ready pod/log-collector-test-pod -n default --timeout=60s 2>&1 | tee -a "$PART3" || true
echo "" >> "$PART3"

echof "Part 3: Inside log-collector pod: list pods across ns and list nodes (expected: allowed)"
echo "==== Part 3: Inside log-collector pod: list pods across ns and list nodes (expected: allowed) ====" >> "$PART3"
kubectl exec -n default log-collector-test-pod -- kubectl get pods --all-namespaces 2>&1 | tee -a "$PART3" || true
echo "" >> "$PART3"
kubectl exec -n default log-collector-test-pod -- kubectl get nodes 2>&1 | tee -a "$PART3" || true
echo "" >> "$PART3"

echof "Part 3: Attempt to get secrets (expected: Forbidden)"
echo "==== Part 3: Attempt to get secrets (expected: Forbidden) ====" >> "$PART3"
kubectl exec -n default log-collector-test-pod -- kubectl get secrets --all-namespaces 2>&1 | tee -a "$PART3" || true
echo "" >> "$PART3"

echof "Cleanup Part 3 pod"
echo "==== Cleanup Part 3 pod ====" >> "$PART3"
kubectl delete pod log-collector-test-pod -n default --ignore-not-found | tee -a "$PART3" "$SUMMARY"
echo "" >> "$PART3"

echof "Part 4: Troubleshooting file exists"
echo "==== Part 4: Troubleshooting file exists ====" >> "$PART4"
ls -l docs/troubleshooting-part4.md | tee -a "$PART4"
echo "" >> "$PART4"

echof "Part 5: Gatekeeper (label enforcement) and automation SA testing"
echo "==== Part 5: Gatekeeper (label enforcement) and automation SA testing ====" >> "$PART5"
kubectl apply -f "$(pwd)/yaml/automation-sa-and-role.yaml" | tee -a "$PART5"
echo "Applying Gatekeeper ConstraintTemplate and Constraint (may fail if Gatekeeper not installed)" | tee -a "$SUMMARY" "$PART5"
kubectl apply -f "$(pwd)/yaml/gatekeeper-pod-label-constrainttemplate.yaml" 2>&1 | tee -a "$PART5" || true
kubectl apply -f "$(pwd)/yaml/gatekeeper-pod-label-constraint.yaml" 2>&1 | tee -a "$PART5" || true
echo "" >> "$PART5"

cat > "$OUTDIR/pod-no-label.yaml" <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-no-label
  namespace: default
spec:
  containers:
  - name: nginx
    image: nginx:alpine
EOF

cat > "$OUTDIR/pod-with-label.yaml" <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-label
  namespace: default
  labels:
    managed-by: automation
spec:
  containers:
  - name: nginx
    image: nginx:alpine
EOF

echof "Try creating pod without label as automation-sa (expected: denied by Gatekeeper if installed)"
echo "==== Try creating pod without label as automation-sa (expected: denied by Gatekeeper if installed) ====" >> "$PART5"
kubectl apply -f "$OUTDIR/pod-no-label.yaml" --as=system:serviceaccount:default:automation-sa 2>&1 | tee -a "$PART5" || true
echo "" >> "$PART5"

echof "Try creating pod with label as automation-sa (expected: allowed)"
echo "==== Try creating pod with label as automation-sa (expected: allowed) ====" >> "$PART5"
kubectl apply -f "$OUTDIR/pod-with-label.yaml" --as=system:serviceaccount:default:automation-sa 2>&1 | tee -a "$PART5" || true
echo "" >> "$PART5"

echof "Cleanup Part 5 test pods"
echo "==== Cleanup Part 5 test pods ====" >> "$PART5"
kubectl delete pod pod-no-label pod-with-label -n default --ignore-not-found 2>&1 | tee -a "$PART5" "$SUMMARY" || true
echo "" >> "$PART5"

echof "Done. Outputs saved to $OUTDIR"

echo ""
echo "Summary of consolidated output files:"
echo "  - part1.txt  : Default ServiceAccount tests"
echo "  - part2.txt  : Monitoring namespace-scoped RBAC tests"
echo "  - part3.txt  : Log collector cluster-wide RBAC tests"
echo "  - part4.txt  : Troubleshooting documentation check"
echo "  - part5.txt  : Automation SA + Gatekeeper label enforcement tests"
echo "  - summary.txt: High-level test execution summary"
echo ""
echo "Helper YAML files for Part 5:"
echo "  - pod-no-label.yaml"
echo "  - pod-with-label.yaml"

exit 0

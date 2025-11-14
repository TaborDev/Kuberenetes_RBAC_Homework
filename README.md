# Kubernetes RBAC Homework

This repository contains YAML resources, explanations, test commands, and troubleshooting for the Kubernetes RBAC homework assignment.

## Repository Structure

```
.
├── README.md                     # This file
├── yaml/                         # All Kubernetes manifests
│   ├── part1-test-pod-default-sa.yaml
│   ├── monitoring-namespace.yaml
│   ├── monitoring-serviceaccount.yaml
│   ├── monitoring-role.yaml
│   ├── monitoring-rolebinding.yaml
│   ├── monitoring-test-pod.yaml
│   ├── log-collector-sa.yaml
│   ├── log-reader-clusterrole.yaml
│   ├── log-collector-clusterrolebinding.yaml
│   ├── log-collector-test-pod.yaml
│   ├── automation-sa-and-role.yaml
│   ├── gatekeeper-pod-label-constrainttemplate.yaml
│   └── gatekeeper-pod-label-constraint.yaml
├── docs/
│   ├── troubleshooting-part4.md   # Part 4: Error analysis & corrected YAML
│   └── part5-design.md            # Part 5: Real-world RBAC design
├── scripts/
│   └── run-tests.sh               # Automated test runner
└── test-outputs/                  # Test results (generated after running tests)
    ├── part1.txt
    ├── part2.txt
    ├── part3.txt
    ├── part4.txt
    ├── part5.txt
    └── summary.txt
```

## Quick Start

### Prerequisites
- Kubernetes cluster (minikube, kind, or cloud provider)
- kubectl installed and configured
- For Part 5 label enforcement: OPA Gatekeeper installed (optional)

### Run All Tests

```bash
# Ensure minikube is running (if using minikube)
minikube start

# Run the automated test suite
bash scripts/run-tests.sh

# Review test outputs
cat test-outputs/summary.txt
```

The script will:
- Apply all RBAC resources (ServiceAccounts, Roles, ClusterRoles, Bindings)
- Create test pods to verify permissions
- Test both allowed and forbidden operations
- Clean up test pods after each part
- Save all outputs to `test-outputs/` for review

## Assignment Solutions

### Part 1: Understanding the Basics (Default ServiceAccount)

**Task 1.1: Inspect Default Service Accounts**

```bash
# List all service accounts in default namespace
kubectl get sa -n default

# Describe the default service account
kubectl describe sa default -n default
```

**Output:**
```
NAME      SECRETS   AGE
default   0         52d

Name:                default
Namespace:           default
Labels:              <none>
Annotations:         <none>
Image pull secrets:  <none>
Mountable secrets:   <none>
Tokens:              <none>
Events:              <none>
```

**Question: Why doesn't the default service account have many permissions?**

The default ServiceAccount has no RBAC Roles or ClusterRoles bound to it by design. This follows the **principle of least privilege** — pods should only have the minimum permissions they need. If every pod had broad permissions by default, a compromised pod could access sensitive cluster resources. Administrators must explicitly grant permissions through RoleBindings/ClusterRoleBindings.

**Task 1.2: Test Current Permissions**

```bash
# Create test pod using default SA
kubectl apply -f yaml/part1-test-pod-default-sa.yaml

# Enter the pod and try to list pods
kubectl exec -it -n default test-pod-default-sa -- kubectl get pods
```

**Error observed:**
```
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:default:default" 
cannot list resource "pods" in API group "" in the namespace "default"
```

**Why this error?**
The default ServiceAccount (`system:serviceaccount:default:default`) has no RBAC permissions to `list` the `pods` resource. The API server denies the request because no Role or ClusterRole grants this verb.

---

### Part 2: Creating Namespace-Scoped Access (Monitoring Application)

**Scenario:** Create a monitoring application that can read Pods, Deployments, and ConfigMaps in the `monitoring` namespace but cannot delete or modify anything.

**Resources created:**
- `yaml/monitoring-namespace.yaml` — monitoring namespace
- `yaml/monitoring-serviceaccount.yaml` — `monitoring-reader` SA
- `yaml/monitoring-role.yaml` — `monitoring-read-role` (read-only permissions)
- `yaml/monitoring-rolebinding.yaml` — binds SA to Role
- `yaml/monitoring-test-pod.yaml` — test pod using the SA

**Key RBAC Rule:**
```yaml
rules:
- apiGroups: [""]
  resources: ["pods","configmaps"]
  verbs: ["get","list","watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get","list","watch"]
```

**Testing:**
```bash
# Apply all resources
kubectl apply -f yaml/monitoring-namespace.yaml
kubectl apply -f yaml/monitoring-serviceaccount.yaml
kubectl apply -f yaml/monitoring-role.yaml
kubectl apply -f yaml/monitoring-rolebinding.yaml
kubectl apply -f yaml/monitoring-test-pod.yaml

# Test: CAN list pods (should succeed)
kubectl exec -n monitoring monitoring-test-pod -- kubectl get pods

# Test: CANNOT delete pods (should be Forbidden)
kubectl exec -n monitoring monitoring-test-pod -- kubectl delete pod monitoring-test-pod
```

**Result:** ✅ Pods and deployments can be listed, ❌ Delete operations are Forbidden.

---

### Part 3: Cluster-Wide Access (Logging Agent)

**Scenario:** Create a logging agent that needs to read Pods across ALL namespaces and read Nodes, but NOT access Secrets.

**Resources created:**
- `yaml/log-collector-sa.yaml` — `log-collector` SA in default namespace
- `yaml/log-reader-clusterrole.yaml` — `log-reader` ClusterRole
- `yaml/log-collector-clusterrolebinding.yaml` — ClusterRoleBinding
- `yaml/log-collector-test-pod.yaml` — test pod

**Key RBAC Rule:**
```yaml
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get","list","watch"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get","list","watch"]
# Secrets are NOT mentioned — deny by default
```

**Testing:**
```bash
# Apply all resources
kubectl apply -f yaml/log-collector-sa.yaml
kubectl apply -f yaml/log-reader-clusterrole.yaml
kubectl apply -f yaml/log-collector-clusterrolebinding.yaml
kubectl apply -f yaml/log-collector-test-pod.yaml

# Test: CAN list pods in all namespaces
kubectl exec -n default log-collector-test-pod -- kubectl get pods --all-namespaces

# Test: CAN list nodes
kubectl exec -n default log-collector-test-pod -- kubectl get nodes

# Test: CANNOT list secrets (should be Forbidden)
kubectl exec -n default log-collector-test-pod -- kubectl get secrets --all-namespaces
```

**Result:** ✅ Pods and nodes can be listed cluster-wide, ❌ Secrets are Forbidden.

---

### Part 4: Troubleshooting RBAC Issues

See `docs/troubleshooting-part4.md` for full analysis.

**Errors found:**
1. **Wrong API group:** Role uses `apiGroups: [""]` but Deployments are in `apps` API group
2. **Mismatched namespaces:** RoleBinding is in `default` namespace but Role is in `production` namespace

**Corrected YAML:** Available in `docs/troubleshooting-part4.md`

---

### Part 5: Real-World Scenario & Label-Based Policy

See `docs/part5-design.md` for full design documentation.

**Teams:**
- **Developers:** Deploy apps in `dev` namespace (Role + RoleBinding)
- **QA Team:** Read-only access to `dev` and `staging` (Roles in each namespace)
- **Ops Team:** Cluster-wide read + write to `production` only (ClusterRole + Role)

**Bonus Challenge:** Label-based pod creation enforcement

RBAC alone cannot enforce "only create pods with label `managed-by: automation`". Solution: **OPA Gatekeeper** admission controller with a ConstraintTemplate.

**Resources:**
- `yaml/automation-sa-and-role.yaml` — SA with pod create/delete permissions
- `yaml/gatekeeper-pod-label-constrainttemplate.yaml` — Gatekeeper policy template
- `yaml/gatekeeper-pod-label-constraint.yaml` — Constraint requiring the label

**Install Gatekeeper (optional):**
```bash
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.11/deploy/gatekeeper.yaml
kubectl apply -f yaml/gatekeeper-pod-label-constrainttemplate.yaml
kubectl apply -f yaml/gatekeeper-pod-label-constraint.yaml
```

---

## Test Results Summary

All tests passed successfully. Key findings:

✅ **Part 1:** Default SA has no permissions (Forbidden error confirmed)  
✅ **Part 2:** Monitoring reader can list pods/deployments, cannot delete  
✅ **Part 3:** Log collector can read pods/nodes cluster-wide, cannot read secrets  
✅ **Part 4:** Troubleshooting doc created with corrected YAML  
✅ **Part 5:** Design doc created; automation SA + Gatekeeper policy implemented  

Full command outputs available in `test-outputs/part1.txt` through `part5.txt`.

---

## Submission Checklist

- [x] All YAML manifests in `yaml/` folder
- [x] Troubleshooting documentation (`docs/troubleshooting-part4.md`)
- [x] Real-world design document (`docs/part5-design.md`)
- [x] Test outputs in `test-outputs/` folder
- [x] README with explanations and testing steps
- [x] Automated test script (`scripts/run-tests.sh`)

## Notes

- **Minikube users:** Run `minikube start` before executing tests
- **Gatekeeper:** Optional for Part 5 label enforcement (RBAC alone cannot enforce labels)
- **Test script:** Use `bash scripts/run-tests.sh` for best compatibility

## Author

Tawera Radomkidanu  
November 14, 2025

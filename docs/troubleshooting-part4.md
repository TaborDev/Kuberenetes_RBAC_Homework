# Troubleshooting Part 4 — deployment-manager

Provided broken YAML (excerpt):

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
 name: deployment-manager
 namespace: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
 name: deployment-role
 namespace: production
rules:
- apiGroups: [""]
 resources: ["deployments"]
 verbs: ["get", "list", "create", "update", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
 name: deployment-binding
 namespace: default
subjects:
- kind: ServiceAccount
 name: deployment-manager
 namespace: production
roleRef:
 kind: Role
 name: deployment-role
 apiGroup: rbac.authorization.k8s.io
```

Issues found (all):

1. Role `deployment-role` references the resource `deployments` but uses apiGroups: [""] (core). Deployments live in API group `apps` (i.e. `apiGroups: ["apps"]`). Using the empty string prevents matching the deployments resource.

2. RoleBinding is in namespace `default`, but the Role it references is in namespace `production`. A RoleBinding is namespaced and can only bind Roles in the same namespace. Because the RoleBinding is in `default`, it cannot reference a Role in `production`.

3. (Minor/implicit) The Role's rules list uses `resources: ["deployments"]` — that is correct resource plural, but as noted the apiGroup is wrong. No other syntactic issues were found.

Corrected YAML (all resources in `production` namespace, Role uses apps API group):

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: deployment-manager
  namespace: production

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployment-role
  namespace: production
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "create", "update", "delete"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deployment-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: deployment-manager
  namespace: production
roleRef:
  kind: Role
  name: deployment-role
  apiGroup: rbac.authorization.k8s.io
```

Why these errors blocked permissions:
- Because the Role used the wrong apiGroup, the rule never matched requests against apps/v1/deployments, so the service account had no matching allowed verb for deployment objects.
- Because the RoleBinding was in the wrong namespace, it did not bind the Role to the ServiceAccount; RoleBindings only bind roles in the same namespace. So even if the Role had correct apiGroup, the RoleBinding would not reference it.

Testing the corrected setup:

1. Apply corrected YAML in the cluster:

  kubectl apply -f corrected-deployment-manager.yaml

2. Test with `kubectl auth can-i` as the service account:

  kubectl auth can-i create deployments --as=system:serviceaccount:production:deployment-manager -n production

Expected result: `yes`

# Part 5 — Real world RBAC design

Teams and needs:

- Developers
  - Need to deploy and manage applications in the `dev` namespace.
  - Actions: create/update/delete Deployments, Services, Pods, ConfigMaps in `dev`.
- QA Team
  - Need read-only access to `dev` and `staging` namespaces.
  - Actions: get/list/watch on core resources and deployments.
- Ops Team
  - Need cluster-wide read access and write access to `production` namespace only.

Design (recommended resources)

ServiceAccounts (per-system components or automation):
- `dev-deployer-sa` in `dev` — used by CI/CD for developer deployments
- `qa-reader-sa` in `qa` (or a central namespace) — used by QA tools
- `ops-admin-sa` in `ops` (or default) — used by ops automation

Roles / ClusterRoles:
- `dev-deployer-role` (Role in `dev`) — permissions to manage deployments, services, pods, configmaps; scoped to `dev` (use Role because namespace-scoped).
- `qa-read-role` (Role in `dev` and `staging`) — read-only on resources in each namespace. Create same Role in both namespaces and bind to QA group/serviceaccount.
- `ops-cluster-read` (ClusterRole) — cluster-wide get/list/watch on cluster resources needed for observability (nodes, pods, namespaces, events). Use ClusterRole because it spans namespaces and nodes.
- `ops-prod-admin` (Role in `production`) — write permissions in `production` for resources ops needs to manage. Keep it a Role to limit to `production` namespace.

Bindings:
- Bind `dev-deployer-role` to `dev-deployer-sa` using RoleBinding in `dev`.
- Bind `qa-read-role` in `dev` and `staging` to `qa-reader-sa` using RoleBinding in each namespace.
- Bind `ops-cluster-read` to `ops-admin-sa` using ClusterRoleBinding (cluster-wide read-only).
- Bind `ops-prod-admin` to `ops-admin-sa` using RoleBinding in `production`.

Justification — Role vs ClusterRole
- Use Role when permissions only need to be applied in a single namespace (principle of least privilege). This reduces blast radius.
- Use ClusterRole when the permission logically crosses namespaces or is about cluster-scoped resources (Nodes, PersistentVolumes, etc.).

Label-based create/delete enforcement

Problem: Require that Pods created/deleted by the automation have label `managed-by: automation`.

Solution chosen: Enforce via an admission policy using OPA Gatekeeper. RBAC alone cannot enforce label-based creation rules. Approach:

1. Create `automation-sa` and grant it ClusterRole with `create`/`delete` on Pods.
2. Install Gatekeeper (instructions below).
3. Add a `ConstraintTemplate` + `Constraint` (provided in `yaml/gatekeeper-*`) that denies Pod create/delete requests unless Pod metadata.labels contains `managed-by: automation`.

Pros:
- Enforces the policy centrally for all creators (not just the SA)
- Keeps RBAC focused on auth; Gatekeeper handles policy checks

Cons:
- Requires Gatekeeper to be installed in the cluster (adds an admission controller).

Gatekeeper install (quick):

  kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.11/deploy/gatekeeper.yaml

Then apply the `ConstraintTemplate` and `Constraint` from `yaml/gatekeeper-pod-label-constrainttemplate.yaml` and `yaml/gatekeeper-pod-label-constraint.yaml`.

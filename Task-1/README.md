# Task Session 1 — Multi-container Pods (Init Container & Sidecar)

## Objective

Deploy an Nginx Hello page on a **3-node Minikube cluster**. Each Pod has one Init Container and two regular containers. The HTML page displays a timestamp that is refreshed every five seconds.

Expected page format:

```text
hello in MLOPS MENA COMMUNITY : YYYY-MM-DD HH:MM:SS
```

## Pod design

| Container | Type | Image | Responsibility |
|---|---|---|---|
| `init-done` | Init Container | `busybox:1.36` | Prints `done` and exits successfully before the regular containers start |
| `nginx` | Main container | `nginx:1.27` | Writes the initial HTML file and serves it on port 80 |
| `time-updater` | Sidecar | `busybox:1.36` | Finds the Nginx master process and updates its HTML file every five seconds through `/proc/<pid>/root` |

The Pod uses `shareProcessNamespace: true`. **No volumes are defined.** The sidecar adds the `SYS_PTRACE` capability as required by the task instructions.

## Files

- `namespace.yaml` — creates the `webapp` namespace.
- `deployment.yaml` — working three-replica Deployment.
- `deployment-fail-init.yaml` — intentional failure variant; the Init Container exits with code 1.
- `deploy.ps1` — applies the namespace and working Deployment.
- `test-failure.ps1` — applies the intentional failure variant and prints the diagnostic commands.
- `recover.ps1` — reapplies the working Deployment and waits for recovery.
- `verify.ps1` — runs the main verification commands.
- `screenshots/` — place submission screenshots here.

## Prerequisites

- Minikube cluster with three nodes and Calico, as required by the task.
- `kubectl` configured to use that Minikube cluster.
- Docker driver available to Minikube.

Example cluster command from the task instructions (run only when the machine has sufficient resources):

```powershell
minikube start -p task1 --driver=docker --nodes=3 --cni=calico --cpus=2 --memory=2200
```

Before continuing, verify:

```powershell
kubectl get nodes
```

All three nodes should show `Ready`.

## 1. Deploy the working application

Open PowerShell in this `Task-1` directory and run:

```powershell
.\deploy.ps1
```

Or run the commands individually:

```powershell
kubectl apply -f .\namespace.yaml
kubectl apply -f .\deployment.yaml
kubectl rollout status deployment/web-deployment -n webapp --timeout=180s
kubectl get pods -n webapp -l app=web -o wide
```

Expected result: three Pods, each showing `2/2 Running`. The completed Init Container is not counted in the regular-container READY column.

## 2. Open the Nginx page and observe the timestamp

In one PowerShell window:

```powershell
kubectl port-forward -n webapp deployment/web-deployment 8080:80
```

Keep that command running. Open a browser at:

<http://localhost:8080>

Refresh the page after five seconds. The timestamp should change.

You can also inspect the file directly:

```powershell
kubectl exec deployment/web-deployment -n webapp -c nginx -- cat /usr/share/nginx/html/index.html
```

Run it twice, at least five seconds apart.

## 3. Verify the multi-container design

```powershell
kubectl get pods -n webapp -l app=web
kubectl logs deployment/web-deployment -n webapp -c init-done
kubectl exec deployment/web-deployment -n webapp -c time-updater -- ps
kubectl get deployment web-deployment -n webapp -o jsonpath='{.spec.template.spec.volumes}'
```

Expected observations:

- Three Pods are Ready; each has `2/2` regular containers.
- Init Container log contains `done`.
- The sidecar can see the Nginx process (look for `nginx: master process`).
- The volumes field is empty.

For the exact container names:

```powershell
kubectl get pods -n webapp -l app=web -o jsonpath='{.items[0].spec.initContainers[*].name}{" | "}{.items[0].spec.containers[*].name}'
```

Expected names: `init-done | nginx time-updater`.

## 4. Intentionally fail the Init Container

First make sure the working Deployment has three Ready Pods. Then run:

```powershell
.\test-failure.ps1
```

Or apply the failure manifest directly:

```powershell
kubectl apply -f .\deployment-fail-init.yaml
```

Watch the Pods:

```powershell
kubectl get pods -n webapp -l app=web -w
```

Use `Ctrl+C` to stop watching. Find the new Pod and inspect it:

```powershell
kubectl logs <new-pod-name> -n webapp -c init-done
kubectl describe pod <new-pod-name> -n webapp
```

Expected observations:

- The new Pod moves through an Init error / `Init:CrashLoopBackOff` state.
- The Init Container exits with code `1` and prints `init failed`.
- The `nginx` and `time-updater` containers in that new Pod do not start because initialization did not succeed.
- With `maxUnavailable: 0` and `maxSurge: 1`, the existing three healthy replicas remain available while the new Pod fails to initialize. The page should remain reachable through the port-forward while at least one healthy Pod remains behind the Deployment.
- The failed rollout is intentional; do not delete the Deployment.

The rollout status command will not complete successfully while the new template is failing. Do not wait indefinitely; inspect the Pods and Events instead.

## 5. Restore the working Deployment

Run:

```powershell
.\recover.ps1
```

Or:

```powershell
kubectl apply -f .\deployment.yaml
kubectl rollout status deployment/web-deployment -n webapp --timeout=180s
kubectl get deployment web-deployment -n webapp
kubectl get pods -n webapp -l app=web -o wide
```

Expected result: Deployment READY `3/3`, and three Pods each showing `2/2 Running`.

## Screenshot checklist

Capture genuine screenshots from your own terminal/browser and save them in `screenshots/`:

1. `01-nodes-ready.png` — three Minikube nodes in `Ready` state.
2. `02-deployment-and-pods.png` — Deployment `3/3` and three Pods `2/2 Running`.
3. `03-nginx-page-timestamp.png` — Nginx page showing the required greeting and timestamp.
4. `04-timestamp-updated.png` — a later timestamp showing the five-second update.
5. `05-init-sidecar-verification.png` — Init Container output and sidecar process listing.
6. `06-init-failure.png` — failed Pod status and Init Container exit code 1.
7. `07-healthy-replicas-during-failure.png` — existing healthy replicas remain Ready and the page remains reachable.
8. `08-recovery.png` — Deployment restored to three Ready replicas.

Do not add screenshots until the corresponding result has actually been observed.

## Cleanup (optional)

Keep the Minikube cluster for later course tasks. To remove only this task's namespace and its resources:

```powershell
kubectl delete namespace webapp
```

## Submission

Place this `Task-1` folder inside the public GitHub repository named **Kubernetes Course Tasks**. Include the YAML files, README and genuine screenshots.

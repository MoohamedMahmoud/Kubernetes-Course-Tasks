# Task Session 1 — Multi-container Pods (Init Container & Sidecar)

## 1. Objective

Deploy an Nginx Hello page on a three-node Minikube Kubernetes cluster.

Each application Pod contains:
- One Init Container that must complete successfully before the application containers start.
- One Nginx main container that serves an HTML page.
- One sidecar container that updates the HTML page's timestamp every five seconds.

The solution uses a shared process namespace to allow the sidecar to locate the Nginx master process and update its HTML file through `/proc/<pid>/root`, without defining application volumes.

**Expected page content:**

```text
hello in MLOPS MENA COMMUNITY : YYYY-MM-DD HH:MM:SS
```

## 2. Kubernetes Environment

| Component | Configuration |
|---|---|
| Operating system | Windows 11 Pro |
| Container runtime | Docker Desktop |
| Kubernetes tool | Minikube v1.39.0 |
| Kubernetes version | v1.37.0 |
| Kubernetes CLI | kubectl |
| Minikube driver | Docker |
| Container runtime inside nodes | containerd |
| Cluster profile | task1 |
| Number of nodes | 3 |
| Container Network Interface | Calico |
| Namespace | webapp |

### Cluster architecture

The cluster consists of one control-plane node and two worker nodes.

| Node | Role | Status |
|---|---|---|
| task1 | Control-plane | Ready |
| task1-m02 | Worker | Ready |
| task1-m03 | Worker | Ready |

All three nodes reached the `Ready` state.

### Cluster creation

For a new Minikube profile, the initial cluster can be created with:

```powershell
minikube start -p task1 `
    --driver=docker `
    --nodes=3 `
    --cni=calico `
    --cpus=2 `
    --memory=2200
```

If the profile already exists with only one node, additional worker nodes can be added using:

```powershell
minikube node add -p task1 --worker
minikube node add -p task1 --worker
```

Verify the cluster:

```powershell
kubectl get nodes -o wide
```

All three nodes should show `Ready`.

## 3. Project Structure

```text
Task-1/
│
├── README.md
├── namespace.yaml
├── deployment.yaml
├── deployment-fail-init.yaml
├── deploy.ps1
├── test-failure.ps1
├── recover.ps1
├── verify.ps1
│
└── screenshots/
    ├── 01-nodes-ready.png
    ├── 02-pods-running.png
    ├── 03-shared-process.png
    ├── 04-timestamp-update.png
    ├── 05-init-failure.png
    ├── 06-init-failure-details.png
    └── 07-recovery-and-final-verification.png
```

## 4. Namespace Configuration

The namespace manifest, `namespace.yaml`, creates the dedicated namespace:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: webapp
```

Apply it using:

```powershell
kubectl apply -f .\namespace.yaml
```

Verify:

```powershell
kubectl get namespaces
```

## 5. Pod Architecture and Container Responsibilities

The Deployment is named `web-deployment`, uses the label `app: web`, and maintains three replicas.

Each Pod contains the following containers:

| Container | Type | Image | Responsibility |
|---|---|---|---|
| init-done | Init Container | busybox:1.36 | Prints `done` and exits successfully before the regular containers start. |
| nginx | Main container | nginx:1.27 | Creates the initial HTML page and serves it on port 80. |
| time-updater | Sidecar | busybox:1.36 | Locates the Nginx master process and updates its HTML file every five seconds. |

### Shared process namespace

The Pod specification includes:

```yaml
shareProcessNamespace: true
```

This allows the sidecar to see the Nginx processes running in the same Pod.

The sidecar uses:

```sh
PID="$(pgrep -o nginx || true)"
```

It then accesses the Nginx container's filesystem through:

```text
/proc/<pid>/root/usr/share/nginx/html/index.html
```

The sidecar also adds the capability required by the task:

```yaml
securityContext:
  capabilities:
    add:
      - SYS_PTRACE
```

**Volumes:** No application volumes are explicitly defined in the Pod template. The HTML file is accessed through the shared process namespace and `/proc/<pid>/root`.

Kubernetes may automatically inject a projected service-account volume into a running Pod. This is separate from application-defined volumes.

## 6. Deploy the Working Application

The working Deployment is defined in:

`deployment.yaml`

It includes:
- Three replicas.
- The `init-done` Init Container.
- The Nginx main container.
- The `time-updater` sidecar.
- A shared process namespace.
- No explicitly defined Pod-template volumes.

The Deployment also uses a rolling-update strategy:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

This preserves the existing available replicas while a replacement Pod is being initialized.

### Deployment command

Run from the `Task-1` directory:

```powershell
.\deploy.ps1
```

Alternatively, apply the resources individually:

```powershell
kubectl apply -f .\namespace.yaml

kubectl apply -f .\deployment.yaml

kubectl rollout status deployment/web-deployment -n webapp --timeout=180s
```

Verify the Deployment and Pods:

```powershell
kubectl get deployment,pods -n webapp -o wide
```

**Expected result:**

- Deployment: `3/3` ready replicas.
- Three application Pods.
- Each Pod: `2/2 Running`.
- The Init Container has completed successfully and is not counted in the regular-container READY column.

## 7. Verify the Init Container

The Init Container must print `done` and exit successfully before Nginx and the sidecar start.

Check its logs:

```powershell
kubectl logs deployment/web-deployment -n webapp -c init-done
```

Expected output:

```text
done
```

The Init Container should have a successful exit code of `0`.

## 8. Verify Shared Process Namespace and Sidecar

Select an application Pod:

```powershell
$Pod = kubectl get pods -n webapp -l app=web -o jsonpath='{.items[0].metadata.name}'
```

Inspect the processes from the sidecar:

```powershell
kubectl exec -n webapp $Pod -c time-updater -- ps
```

Expected output includes:

```text
nginx: master process nginx -g daemon off;
nginx: worker process
```

This confirms that the sidecar can see the Nginx processes through the shared process namespace.

### Verify container names

```powershell
kubectl get pod -n webapp $Pod -o jsonpath='{.spec.initContainers[*].name}'

kubectl get pod -n webapp $Pod -o jsonpath='{.spec.containers[*].name}'
```

Expected names:

```text
init-done
```

```text
nginx time-updater
```

## 9. Verify the Dynamic Timestamp

The Nginx container initially writes the required greeting into:

```text
/usr/share/nginx/html/index.html
```

The sidecar updates this file continuously.

Check the HTML content:

```powershell
kubectl exec -n webapp $Pod -c nginx -- cat /usr/share/nginx/html/index.html
```

Wait six seconds:

```powershell
Start-Sleep -Seconds 6
```

Read the file again:

```powershell
kubectl exec -n webapp $Pod -c nginx -- cat /usr/share/nginx/html/index.html
```

Expected content:

```html
<h1>hello in MLOPS MENA COMMUNITY : 2026-11-07 HH:MM:SS</h1>
```

The timestamp should change between successive checks.

### Browser access

The Nginx application can be accessed locally using port forwarding.

Run:

```powershell
kubectl port-forward -n webapp deployment/web-deployment 8080:80
```

Keep the command running and open:

http://localhost:8080

The browser should display the greeting and timestamp.

Refresh the page after five seconds to observe the updated timestamp.

## 10. Verify the No-Volumes Requirement

Inspect the Pod template:

```powershell
kubectl get deployment web-deployment -n webapp -o jsonpath='{.spec.template.spec.volumes}'
```

Expected result: empty output.

This confirms that no application volumes are defined in the Deployment's Pod template.

## 11. Intentional Init Container Failure

The assignment requires testing what happens when the Init Container fails.

The failure configuration is provided in:

`deployment-fail-init.yaml`

The Init Container command is changed to:

```sh
echo 'init failed'; exit 1
```

This prints `init failed` and terminates with exit code `1`.

### Apply the failure configuration

First ensure the working application has three available replicas.

Run:

```powershell
.\test-failure.ps1
```

Alternatively:

```powershell
kubectl apply -f .\deployment-fail-init.yaml
```

Watch the Pods:

```powershell
kubectl get pods -n webapp -w
```

Stop watching with `Ctrl+C` after the failed Pod appears.

### Expected observations

- Kubernetes creates a new Pod for the updated Deployment.
- The new Pod enters an Init error state, eventually showing `Init:CrashLoopBackOff`.
- The Init Container repeatedly terminates with exit code `1`.
- The Nginx and sidecar containers in that failed Pod do not start.
- The original three healthy Pods remain `2/2 Running`.

The rolling-update configuration uses `maxUnavailable: 0` and `maxSurge: 1`, preserving the three original available replicas during this failed update.

### Inspect the failed Pod

Identify the failed Pod:

```powershell
kubectl get pods -n webapp
```

Assign its actual name:

```powershell
$FailedPod = "REPLACE_WITH_ACTUAL_FAILED_POD_NAME"
```

Inspect the Init Container logs:

```powershell
kubectl logs -n webapp $FailedPod -c init-done
```

Expected output:

```text
init failed
```

Inspect its details:

```powershell
kubectl describe pod $FailedPod -n webapp
```

Important evidence:

```text
Reason:       Error
Exit Code:    1
```

The Pod's initialization condition should remain false, and its application containers should remain unstarted.

### Verify healthy replicas during failure

```powershell
kubectl get deployment,pods -n webapp
```

The original three Pods should remain available while the new failed Pod is unable to initialize.

To test browser access specifically during this failure, port-forward directly to one of the original healthy Pods:

```powershell
kubectl port-forward -n webapp pod/REPLACE_WITH_HEALTHY_POD_NAME 8080:80
```

Keep the port-forward running and open:

http://localhost:8080

The existing healthy Nginx Pod should continue serving the page.

Note: The failed rollout is intentional. Do not delete the Deployment. The rollout will not complete successfully until the working configuration is restored.

## 12. Restore the Working Deployment

After capturing the failure evidence, restore the original configuration:

```powershell
.\recover.ps1
```

Alternatively:

```powershell
kubectl apply -f .\deployment.yaml

kubectl rollout status deployment/web-deployment -n webapp --timeout=180s
```

Verify the final state:

```powershell
kubectl get deployment,pods -n webapp -o wide
```

**Expected result:**

```text
Deployment READY: 3/3
```

All three Pods should show:

```text
READY:  2/2
STATUS: Running
```

The failed Pod should be removed during the successful rollout.

## 13. Final Verification

Run the verification script:

```powershell
.\verify.ps1
```

The main verification commands are:

```powershell
kubectl get nodes -o wide

kubectl get deployment -n webapp

kubectl get pods -n webapp -o wide

kubectl logs deployment/web-deployment -n webapp -c init-done

kubectl exec deployment/web-deployment -n webapp -c time-updater -- ps

kubectl get deployment web-deployment -n webapp -o jsonpath='{.spec.template.spec.volumes}'
```

The final checks should confirm:

- Three Kubernetes nodes in `Ready` state.
- Deployment with three available replicas.
- Three Pods with two running regular containers each.
- Successful Init Container execution.
- Nginx processes visible from the sidecar.
- Dynamic HTML timestamp updates.
- No explicitly defined Pod-template volumes.
- Successful recovery after the intentional Init Container failure.

## 14. Screenshots and Evidence

The `screenshots/` directory contains terminal evidence captured during the actual implementation.

| Screenshot | Evidence |
|---|---|
| `01-nodes-ready.png` | Three Minikube nodes showing `Ready`. |
| `02-pods-running.png` | Three application Pods showing `2/2 Running`. |
| `03-shared-process.png` | Nginx master and worker processes visible from the sidecar. |
| `04-timestamp-update.png` | HTML content showing the changing timestamp. |
| `05-init-failure.png` | Intentional Init Container failure and failed Pod state. |
| `06-init-failure-details.png` | Init Container logs and failure details, including exit code 1. |
| `07-recovery-and-final-verification.png` | Successful restoration and final healthy Deployment. |

Additional browser screenshots can be included after completing the browser access and failure-availability checks.

All screenshots should be genuine captures from the local PowerShell terminal or browser. Do not substitute generated or simulated output for actual test evidence.

## 15. Cleanup (Optional)

The Minikube cluster can be retained for subsequent course tasks.

To remove only this application's resources:

```powershell
kubectl delete namespace webapp
```

This removes the `webapp` namespace and its resources without deleting the Minikube cluster.

## 16. Submission

The project is organized under the public GitHub repository:

**Kubernetes Course Tasks**

Repository:

https://github.com/MoohamedMahmoud/Kubernetes-Course-Tasks

The repository contains the `Task-1/` directory with:

- Kubernetes namespace and Deployment manifests.
- Intentional failure configuration.
- PowerShell deployment, failure-testing, recovery and verification scripts.
- Project documentation.
- Implementation screenshots.

The purpose of this submission is to demonstrate the use of Init Containers, multi-container Pods, shared process namespaces, sidecar containers, rolling updates, failure behavior and application recovery in Kubernetes.

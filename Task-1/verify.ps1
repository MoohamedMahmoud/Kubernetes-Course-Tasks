$ErrorActionPreference = 'Stop'

Write-Host '=== Nodes ===' -ForegroundColor Cyan
kubectl get nodes -o wide

Write-Host '=== Deployment ===' -ForegroundColor Cyan
kubectl get deployment web-deployment -n webapp

Write-Host '=== Pods ===' -ForegroundColor Cyan
kubectl get pods -n webapp -l app=web -o wide

Write-Host '=== Init container names and regular container names ===' -ForegroundColor Cyan
kubectl get pods -n webapp -l app=web -o jsonpath='{.items[0].spec.initContainers[*].name}{" | "}{.items[0].spec.containers[*].name}{"`n"}'

Write-Host '=== Init container output ===' -ForegroundColor Cyan
kubectl logs deployment/web-deployment -n webapp -c init-done

Write-Host '=== Sidecar process view ===' -ForegroundColor Cyan
kubectl exec deployment/web-deployment -n webapp -c time-updater -- ps

Write-Host '=== Nginx-served HTML ===' -ForegroundColor Cyan
kubectl exec deployment/web-deployment -n webapp -c nginx -- cat /usr/share/nginx/html/index.html

Write-Host '=== Pod template volumes (empty output means no volumes) ===' -ForegroundColor Cyan
kubectl get deployment web-deployment -n webapp -o jsonpath='{.spec.template.spec.volumes}'
Write-Host ''

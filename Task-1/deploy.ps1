$ErrorActionPreference = 'Stop'

Write-Host 'Applying namespace...' -ForegroundColor Cyan
kubectl apply -f .\namespace.yaml

Write-Host 'Applying working Deployment...' -ForegroundColor Cyan
kubectl apply -f .\deployment.yaml

Write-Host 'Waiting for the Deployment to become ready...' -ForegroundColor Cyan
kubectl rollout status deployment/web-deployment -n webapp --timeout=180s

Write-Host 'Deployment:' -ForegroundColor Green
kubectl get deployment web-deployment -n webapp

Write-Host 'Pods:' -ForegroundColor Green
kubectl get pods -n webapp -l app=web -o wide

$ErrorActionPreference = 'Stop'

Write-Host 'Restoring the working Init Container command...' -ForegroundColor Cyan
kubectl apply -f .\deployment.yaml

Write-Host 'Waiting for all three replicas to become ready...' -ForegroundColor Cyan
kubectl rollout status deployment/web-deployment -n webapp --timeout=180s

Write-Host 'Final Deployment:' -ForegroundColor Green
kubectl get deployment web-deployment -n webapp

Write-Host 'Final Pods:' -ForegroundColor Green
kubectl get pods -n webapp -l app=web -o wide

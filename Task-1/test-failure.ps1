$ErrorActionPreference = 'Stop'

Write-Host 'Applying the intentional Init Container failure...' -ForegroundColor Yellow
kubectl apply -f .\deployment-fail-init.yaml

Write-Host 'Current Pods (healthy old replicas should remain available):' -ForegroundColor Cyan
kubectl get pods -n webapp -l app=web -o wide

Write-Host 'ReplicaSets:' -ForegroundColor Cyan
kubectl get replicasets -n webapp -l app=web

Write-Host 'Wait a few seconds, then run:' -ForegroundColor Yellow
Write-Host 'kubectl get pods -n webapp -l app=web -w'
Write-Host 'kubectl logs <new-pod-name> -n webapp -c init-done'
Write-Host 'kubectl describe pod <new-pod-name> -n webapp'
Write-Host 'The failed rollout is intentional. Do not delete the Deployment.'

## deploy argocd application contains all k8s resources
kubectl.exe apply -f .\argocd-application.yaml
kubectl.exe apply -f .\prometheus-grafana-application.yaml







kubectl get pods -n monitoring
kubectl get svc -n monitoring
kubectl describe pod mon-grafana-dfdfdbd7b-9wwjq -n monitoring
kubectl describe svc mon-grafana -n monitoring
kubectl get ingress -n monitoring

kubectl.exe delete -f .\yaml\prometheus-grafana-application.yaml
kubectl.exe delete -f .\yaml\grafana-ingress.yaml
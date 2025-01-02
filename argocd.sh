#!/bin/bash

 kubectl create ns argocd
 kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
 kubectl get svc argocd-server -n argocd -o yaml > argocd.yaml
 sed -i '5i \ \ \ \ cloud.google.com/load-balancer-type: Internal' argocd.yaml
 kubectl apply -f argocd.yaml
 kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
 kubectl delete netpol argocd-repo-server-network-policy -n argocd
 kubectl create namespace argocd
 cat <<EOF > argoegress.yaml
 apiVersion: networking.k8s.io/v1
 kind: NetworkPolicy
 metadata:
   name: allow-all-egress
 spec:
   podSelector: {}
   egress:
   - {}
   policyTypes:
   - Egress
 EOF
 kubectl apply -f argoegress.yaml
 echo "tungguin bentar nunggu password argocd belom up itu servicenya"
 sleep 15s
 echo "tungguin aje ntar juga keluar"
 sleep 30s
 echo ""
 echo ""
 echo "ni password argonya"
 kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
 sleep 30s
 echo "ini ip loadbalancernya"
 kubectl get svc -n argocd |grep -i loadbalancer |awk '{ print $4 }'
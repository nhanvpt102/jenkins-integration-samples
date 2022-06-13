#!/bin/bash

echo "Step 1: Create a namespace 'devops-tools' for Jenkins."
# kubectl create namespace devops-tools

echo "Step 2: Create a serviceAccount 'jenkins-admin'"
# kubectl apply -f serviceAccount.yaml

echo "Step 3: Create volume 'jenkins-pv-claim'"
# kubectl create -f volume.yaml

echo "Step 4: Create a Deployment 'jenkins'"
kubectl apply -f deployment.yaml

#Step 5: Create service.yaml
kubectl apply -f service.yaml

# kubectl -n devops-tools port-forward svc/jenkins-service 8080:8080 &>/tmp/jenkins8080.log &
# VPT123vpt!
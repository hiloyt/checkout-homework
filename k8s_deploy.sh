#!/bin/bash

REPO_URL=$(terraform output -raw --state terraform/terraform.tfstate repository_url)
sed -Ei "s|CM_IMAGE_LOC|$REPO_URL|g" k8s-resources-aws/deployment.yaml
kubectl create ns app-checkout
kubectl apply -f k8s-resources-aws/ -n app-checkout
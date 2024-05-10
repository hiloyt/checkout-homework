#!/bin/bash

ACC_ID=$(terraform output -raw --state terraform/terraform.tfstate repository_registry_id)
REPO_URL=$(terraform output -raw --state terraform/terraform.tfstate repository_url)
CLUSTER_NAME=$(terraform output -raw --state terraform/terraform.tfstate cluster_name)
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin $ACC_ID.dkr.ecr.eu-west-2.amazonaws.com
docker build -t $REPO_URL:latest -f app/Dockerfile .
docker push $REPO_URL:latest
aws eks --region eu-west-2 update-kubeconfig --name $CLUSTER_NAME
kubectl cluster-info
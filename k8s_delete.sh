#!/bin/bash

kubectl delete -f k8s-resources-aws/ -n app-checkout
aws ecr batch-delete-image --repository-name checkout-homework --image-ids imageTag=latest > /dev/null 2>&1
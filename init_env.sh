#!/bin/bash

# Read input from the user
read -p "Enter the Git-Hub repository URL: " GIT_REPO_URL
read -p "Enter the workshop user: " WORKSHOP_USER
read -p "Enter the workshop Cluster API URL: " WORKSHOP_API_URL
read -p "Enter the workshop Password: " WORKSHOP_PASSWORD
read -p "Enter the Git-Hub username: " GITHUB_USERNAME
read -p "Enter your GitHub personal access token: " GHCR_TOKEN
read -p "Enter your email address: " EMAIL

# Update the PipelineRun.yaml file
yq e ".metadata.generateName = \"$WORKSHOP_USER-dotnet-app-\"" -i PipelineRun.yaml
yq e ".spec.params[0].value = \"$GIT_REPO_URL\"" -i PipelineRun.yaml
yq e ".spec.params[1].value = \"$GITHUB_USERNAME\"" -i PipelineRun.yaml
yq e ".spec.params[4].value = \"$WORKSHOP_USER-application\"" -i PipelineRun.yaml
yq e ".spec.pipelineRef.name = \"$WORKSHOP_USER-dotnet-app\"" -i PipelineRun.yaml

# Get the latest OC client
wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux.tar.gz
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
wget https://mirror.openshift.com/pub/openshift-v4/clients/pipeline/latest/tkn-linux-amd64.tar.gz

tar xvf openshift-client-linux.tar.gz --no-same-owner
tar xvf tkn-linux-amd64.tar.gz --no-same-owner


rm -rf /tmp/runs
mkdir /tmp/runs
chmod +x yq_linux_amd64 
mv yq_linux_amd64 /tmp/runs/yq
mv oc kubectl tkn tkn-pac opc /tmp/runs

export PATH=$(echo "${PATH}:/tmp/runs")

# Set the WORKSHOP_USER environment variable
export WORKSHOP_USER

rm openshift-client-linux.tar.gz README.md tkn-linux-amd64.tar.gz LICENSE

oc login -u $WORKSHOP_USER -p $WORKSHOP_PASSWORD $WORKSHOP_API_URL --insecure-skip-tls-verify=true


# Create the k8s imagePull Secret for ghcr.io
oc create secret docker-registry ghcr-secret \
    --docker-server=ghcr.io \
    --docker-username=$GITHUB_USERNAME \
    --docker-password=$GHCR_TOKEN \
    --docker-email=$EMAIL

# Patch the serviceAccount pipeline to use the imagePull Secret
oc patch serviceaccount pipeline -p '{"imagePullSecrets":[{"name":"ghcr-secret"}]}'

# Add the created secret as a secret to the service account
oc patch serviceaccount pipeline -p '{"secrets":[{"name":"ghcr-secret"}]}'

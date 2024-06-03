#!/bin/bash

# Source the environment variables file if it exists
if [ -f ./env_vars.sh ]; then
  source ./env_vars.sh
fi

# Function to read input if the variable is not already set
get_input() {
  local var_name=$1
  local prompt=$2
  if [ -z "${!var_name}" ]; then
    read -p "$prompt" $var_name
    echo "export $var_name=\"${!var_name}\"" >> ./env_vars.sh
  fi
}

# Check and read the necessary environment variables
get_input "GITHUB_USERNAME" "Enter the Git-Hub username: "
get_input "GHCR_TOKEN" "Enter your GitHub personal access token: "
get_input "EMAIL" "Enter your email address: "
get_input "GIT_REPO_URL" "Enter the Git-Hub repository URL: "
get_input "CLUSTER_FQDN" "Enter the workshop cluster FQDN: "
get_input "WORKSHOP_USER" "Enter the workshop user: "
get_input "WORKSHOP_API_URL" "Enter the workshop Cluster API URL: "
get_input "WORKSHOP_PASSWORD" "Enter the workshop Password: "

# Directory to store the binaries
RUNS_DIR="/tmp/runs"

# Function to download and extract files if they don't already exist
download_and_extract() {
  local url=$1
  local tar_file=$(basename $url)
  local binary_name=$2

  if [ ! -f $RUNS_DIR/$binary_name ]; then
    wget $url -O $tar_file
    if [[ $tar_file == *.tar.gz ]]; then
      tar xvf $tar_file --no-same-owner -C $RUNS_DIR || { echo "Failed to extract $tar_file"; rm $tar_file; return 1; }
    else
      chmod +x $tar_file
      mv $tar_file $RUNS_DIR/$binary_name
    fi
    rm $tar_file
  else
    echo "$binary_name already exists in $RUNS_DIR, skipping download."
  fi
}

# Create the runs directory if it doesn't exist
mkdir -p $RUNS_DIR

# Download and extract the necessary binaries
download_and_extract "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux.tar.gz" "oc"
download_and_extract "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" "yq"
download_and_extract "https://mirror.openshift.com/pub/openshift-v4/clients/pipeline/latest/tkn-linux-amd64.tar.gz" "tkn"
download_and_extract "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64" "argocd"

# Move binaries to the runs directory if they are not already there
for binary in oc kubectl tkn tkn-pac yq_linux_amd64 argocd; do
  if [ -f $binary ]; then
    chmod +x $binary
    mv $binary $RUNS_DIR
  fi
done

# Set the PATH to include the runs directory
export PATH="${PATH}:${RUNS_DIR}"

# Set the WORKSHOP_USER environment variable
export WORKSHOP_USER

rm -f openshift-client-linux.tar.gz README.md tkn-linux-amd64.tar.gz LICENSE

# Update the PipelineRun.yaml file
yq e ".metadata.generateName = \"$WORKSHOP_USER-dotnet-app-\"" -i GitOps/PipelineRun.yaml
yq e ".spec.params[0].value = \"$GIT_REPO_URL\"" -i GitOps/PipelineRun.yaml
yq e ".spec.params[1].value = \"$GITHUB_USERNAME\"" -i GitOps/PipelineRun.yaml
yq e ".spec.params[4].value = \"$WORKSHOP_USER-application\"" -i GitOps/PipelineRun.yaml
yq e ".spec.pipelineRef.name = \"$WORKSHOP_USER-dotnet-app\"" -i GitOps/PipelineRun.yaml

# Update the argo-app.yaml file
yq e ".spec.destination.namespace = \"$WORKSHOP_USER-application\"" -i GitOps/Argo-App.yaml
yq e ".spec.sources[1].repoURL = \"$GIT_REPO_URL\"" -i GitOps/Argo-App.yaml

# Update the values.yaml file
yq e ".global.nameOverride = \"$WORKSHOP_USER\"" -i GitOps/values.yaml
yq e ".global.namespace = \"$WORKSHOP_USER-application\"" -i GitOps/values.yaml
yq e ".deploy.ingress.Domain = \"$CLUSTER_FQDN\"" -i GitOps/values.yaml

# Log in to the OpenShift cluster
oc login -u $WORKSHOP_USER -p $WORKSHOP_PASSWORD $WORKSHOP_API_URL --insecure-skip-tls-verify=true

# Set the project
oc project $WORKSHOP_USER-application

# Apply the Argo CD application
oc apply -f GitOps/Argo-App.yaml -n $WORKSHOP_USER-argocd

# Create the k8s imagePull Secret for ghcr.io
oc create secret docker-registry ghcr-secret \
    --docker-server=ghcr.io \
    --docker-username=$GITHUB_USERNAME \
    --docker-password=$GHCR_TOKEN \
    --docker-email=$EMAIL \
    -n $WORKSHOP_USER-argocd

# Patch the serviceAccount pipeline to use the imagePull Secret
oc patch serviceaccount pipeline -p '{"imagePullSecrets":[{"name":"ghcr-secret"}]}'

# Add the created secret as a secret to the service account
oc patch serviceaccount pipeline -p '{"secrets":[{"name":"ghcr-secret"}]}'

# Commit latest changes
git commit -am "Init Env ended"
git push

#!/bin/bash

# Ensure the runs directory is in the PATH
export PATH="${PATH}:/tmp/runs"

# Source environment variables
if [ -f env_vars.sh ]; then
  source env_vars.sh
else
  echo "env_vars.sh file not found. Please ensure it exists in the current directory."
  exit 1
fi

# Extract the numeric part of the tag from the PipelineRun.yaml
TAG=$(yq eval ".spec.params[3].value" GitOps/PipelineRun.yaml)
NUMERIC_TAG=$(echo "$TAG" | sed 's/[^0-9]*//g')

# Check if the numeric part was extracted successfully
if [ -z "$NUMERIC_TAG" ]; then
  echo "Error: No numeric part found in the tag."
  exit 1
fi

# Increment the numeric part of the tag by one
NEW_NUMERIC_TAG=$((NUMERIC_TAG + 1))

# Construct the new tag with the incremented numeric part
NEW_TAG="v$NEW_NUMERIC_TAG"

# Update the GitOps/PipelineRun.yaml file with the new tag value
yq eval ".spec.params[3].value = \"$NEW_TAG\"" -i GitOps/PipelineRun.yaml
echo "Increased image version tag to $NEW_TAG"

# Run the PipelineRun and capture the output
PR_OUTPUT=$(oc create -f GitOps/PipelineRun.yaml -n $WORKSHOP_USER-argocd)
if [ $? -ne 0 ]; then
  echo "Error: Failed to create PipelineRun."
  exit 1
fi

# Extract the PipelineRun name from the output
PIPELINE_RUN_NAME=$(echo "$PR_OUTPUT" | awk '{print $1}' | awk -F/ '{print $NF}')
if [ -z "$PIPELINE_RUN_NAME" ]; then
  echo "Error: Failed to extract PipelineRun name."
  exit 1
fi

echo "Running New Pipeline with PipelineRun: $PIPELINE_RUN_NAME"

# Get the logs for the PipelineRun
tkn pr logs "$PIPELINE_RUN_NAME" -n "$WORKSHOP_USER-argocd" -f

# Patch the values.yaml file with the new image and tag
yq eval ".image.name = \"ghcr.io/$GITHUB_USERNAME/dotnet-app\"" -i GitOps/values.yaml
yq eval ".image.tag = \"$NEW_TAG\"" -i GitOps/values.yaml

# Commit the changes to git
git commit -am "new image tag"
if [ $? -ne 0 ]; then
  echo "Error: Git commit failed."
  exit 1
fi

git push
if [ $? -ne 0 ]; then
  echo "Error: Git push failed."
  exit 1
fi

# Sync the Argo CD application
argocd app sync $WORKSHOP_USER-dotnet-app
if [ $? -ne 0 ]; then
  echo "Error: Argo CD sync failed."
  exit 1
fi

# Get the OpenShift Ingress host and construct the application link
APP_LINK="https://$(oc get ingress $WORKSHOP_USER-dotnet-app -n $WORKSHOP_USER-application -o yaml | yq '.spec.rules[0].host')/swagger/index.html"
if [ -z "$APP_LINK" ]; then
  echo "Error: Failed to retrieve the application link."
  exit 1
fi

echo "To access the Application use this link: ${APP_LINK}"

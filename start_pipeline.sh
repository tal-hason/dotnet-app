#!/bin/bash

export PATH=$(echo "${PATH}:/tmp/runs")

source env_vars.sh

# Extract the numeric part of the tag
TAG=$(yq eval ".spec.params[3].value" GitOps/PipelineRun.yaml)
NUMERIC_TAG=$(echo $TAG | sed 's/[^0-9]*//g')

# Increment the numeric part of the tag by one
NEW_NUMERIC_TAG=$((NUMERIC_TAG + 1))

# Construct the new tag with the incremented numeric part
NEW_TAG="v$NEW_NUMERIC_TAG"

# Update the GitOps/PipelineRun.yaml file with the new tag value
yq eval ".spec.params[3].value = \"$NEW_TAG\"" -i GitOps/PipelineRun.yaml

echo "Increased image version tag to $NEW_TAG"

# Run the PipelineRun and capture the output
PR_OUTPUT=$(oc create -f GitOps/PipelineRun.yaml -n $WORKSHOP_USER-argocd)

# Extract the PipelineRun name from the output
PIPELINE_RUN_NAME=$(echo "$PR_OUTPUT" | awk '{print $1}' | awk -F/ '{print $NF}')

echo "Running New Pipeline with PipelineRun: $PIPELINE_RUN_NAME"

# Get the logs for the PipelineRun
tkn pr logs $PIPELINE_RUN_NAME -n $WORKSHOP_USER-argocd -f

# Patch the Values file with the new image and tag
yq eval ".image.name = \"ghcr.io\$GITHUB_USERNAME\"" -i GitOps/values.yaml
yq eval ".image.tag = \"$NEW_TAG\"" -i GitOps/values.yaml

git commit -am "new image tag"

git push

export APP_LINK=https://$(oc get ingress $WORKSHOP_USER-dotnet-app -n $WORKSHOP_USER-application -o yaml | yq '.spec.rules[0].host')/swagger/index.html

echo "To access the Application use this  link: ${APP_LINK}"
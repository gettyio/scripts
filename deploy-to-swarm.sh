#! /bin/bash

# Necessary env vars:
# DEV_SSH: base64 encoded development private key
# DEV_CONFIG: base64 encoded ssh configuration for docker manager
# PROJECT_NAME: project name without description, eg. use project-name instead of project-name-api
# PROJECT_PORT: which port the project runs on
# ECS_REPOSITORY: the ecs repository, eg. 00000000.dkr.ecr.us-east-1.amazonaws.com/development

# Save private key
echo $DEV_SSH | base64 -d > ~/.ssh/development.pem
chmod 400 ~/.ssh/development.pem

# Save configuration
echo $DEV_CONFIG | base64 -d >> ~/.ssh/config

docker build -t ${PROJECT_NAME} .
eval $(aws ecr get-login --region us-east-1)
docker tag ${PROJECT_NAME} ${ECS_REPOSITORY}:${PROJECT_NAME}
docker push ${ECS_REPOSITORY}:${PROJECT_NAME}

ssh docker-manager $(aws ecr get-login --no-include-email --region us-east-1)


# Check if service is already running
result=$(ssh docker-manager docker service ls --filter name=${PROJECT_NAME} -q)

if [[ -n "$result" ]]; then
  ssh docker-manager docker service update \
    --with-registry-auth \
    --label-add ingress.dnsname=${PROJECT_NAME}-api.dev.gettydata.com \
    --label-add ingress.targetport=${PROJECT_PORT} \
    --force -q --detach=false \
    ${PROJECT_NAME}
else
  ssh docker-manager docker service create \
    --with-registry-auth \
    --name ${PROJECT_NAME} \
    --label ingress=true \
    --label ingress.dnsname=${PROJECT_NAME}-api.dev.gettydata.com \
    --label ingress.targetport=${PROJECT_PORT} \
    --network frontends \
    -q --detach=false \
    ${ECS_REPOSITORY}:${PROJECT_NAME}
fi

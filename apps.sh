#!/bin/bash

# getting credentials from credentials.txt file 
source ./config.sh

# Github Credential 
gurl=$github_url

#Github Branchname to clonning specific branch
branch=$gbranch

# Argocd URL
argourl=$argocdurl

# Application namespace on argocd 
namespace=$k8snamespace

# cloning repo with specific branch on dep_repo directory 
git clone -b $gbranch --single-branch "https://${GIT_USERNAME}:${GIT_PASSWORD}@${gurl}" dep_repo

export apps=$appname
export max=$maxreplicas
export min=$minreplicas

if [[ ${maxreplicas} == "0" && ${minreplicas} == "0" ]] 
then
   
    argocd app delete-resource $namespace --kind Rollout --all 
else
    if [[ $ws == $desiredapps ]]
    then
    # To change maxreplicas as per user input for scale up and down application
    yq -i 'select(.metadata.name == env(apps)).spec.maxReplicas |= env(max)' dep_repo/manifest.yaml
    yq -i 'select(.metadata.name == env(apps)).spec.minReplicas |= env(min)' dep_repo/manifest.yaml
    
    else
    # To change maxreplicas as per user input for scale up and down application  
    yq -i 'select(.metadata.name == env(apps)).spec.maxReplicas |= env(max)' dep_repo/manifest.yaml
    yq -i 'select(.metadata.name == env(apps)).spec.minReplicas |= env(min)' dep_repo/manifest.yaml

    echo "changed the replicas"
    fi
# commiting changes to repository
    git config --global user.email ${GIT_USERNAME}
    git -C dep_repo add .
    git -C dep_repo commit -m "maxReplicas or minreplcias as per user input reflect on manifest yaml file"

# pushing changes to public repository 
    git -C dep_repo push

# performing argocd sync for specific application 
    argocd app sync $namespace
    argocd app wait $namespace --operation
fi
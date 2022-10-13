#!/bin/bash

# getting credentials from credentials.txt file 
source variables.sh

# Github Credential 
gurl=$github_url

#Github Branchname to clonning specific branch
branch=$gbranch

# Argocd URL
argourl=$argocdurl

# Replicas number
#replicas=$maxreplicas
#oldreplicas="replicas: $(cat manifest.yaml | grep replicas | awk '{print $2}')"
#newreplicas="replicas: $replicas"

# Application namespace on argocd 
namespace=$k8snamespace

# To delete old directory if persist
    rm -rf pts-dev

# cloning repo with specific branch on pts-dev directory 
    git clone -b $branch --single-branch $gurl pts-dev && cd pts-dev

#replicas=$maxreplicas
oldreplicas="maxReplicas: $(cat manifest.yaml | grep maxReplicas | awk '{print $2}')"
newreplicas="maxReplicas: $maxreplicas"

# To change maxreplicas 1 to 0 for scale down application  
   # sed -i '' -e "s/maxReplicas: 1/maxReplicas: 0/g" manifest.yaml
   sed -i '' -e "s/$oldreplicas/$newreplicas/g" manifest.yaml

# commiting changes to repository 
    git add .
    git commit -m "maxReplicas change one to zero"

# pushing changes to public repository 
#git push origin $branch

# argocd login 
   argocd login $argourl --sso --insecure

# performing argocd sync for specific application 
    argocd app get $namespace

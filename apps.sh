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

echo $gurl
echo $gbranch
echo $namespace
# cloning repo with specific branch on pts-dev directory 
git clone "https://${GIT_USERNAME}:${GIT_PASSWORD}@${gurl}" 

# cloning repo with specific branch on pts-dev directory 
    #git clone -b $branch --single-branch $gurl 

#replicas=$maxreplicas
oldmaxreplicas="maxReplicas: $(cat test/manifest.yaml | grep maxReplicas | awk '{print $2}')"
newmaxreplicas="maxReplicas: $maxreplicas"

# To change maxreplicas as per user input for scale up and down application  
   sed -i '' -e "s/$oldmaxreplicas/$newmaxreplicas/g" test/manifest.yaml

#replicas=$minreplicas
oldminreplicas="minReplicas: $(cat test/manifest.yaml | grep minReplicas | awk '{print $2}')"
newminreplicas="minReplicas: $minreplicas"

# To change minreplicas as per user input for scale up and down application  
   sed -i '' -e "s/$oldminreplicas/$newminreplicas/g" test/manifest.yaml

# commiting changes to repository 
    git -C test add .
    git -C test commit -m "maxReplicas or minreplcias as per user input reflect on manifest yaml file"

# pushing changes to public repository 
#git push origin $branch

# performing argocd sync for specific application 
    argocd app get $namespace
   #argocd app sync $namespace

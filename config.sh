#!/bin/bash

# echo "Choose your service (JSS PTS ADE): "
svc=$1

# echo "Choose your Environment :- (QA PROD PRF) "
env=$2

# echo "Choose AWS Region :- (USE2 USW2) "
region=$3

# Provide max number of replicas (maxreplicas)
maxreplicas=$4

# Provide min number of replicas (minreplicas)
minreplicas=$5

ws="${svc}-${env}-${region}"

case $ws in 
"payroll-metrics-qal-usw2") echo "your env is pts-qal-usw2"

    github_url=https://{$GIT_USERNAME}:{$GIT_PASSWORD}@github.intuit.com/payroll-payrolltax/payroll-metrics-deployment.git
    argocdurl=payroll.argocd.tools-k8s-prd.a.intuit.com
    gbranch=environments/qal-usw2-eks 
    k8snamespace=payroll-payrollmetrics-usw2-qal
    ;;

"payroll-metrics-prod-usw2") echo "your env is pts-prod-usw2"

    github_url=https://github.intuit.com/payroll-payrolltax/payroll-metrics-deployment.git
    argocdurl=payroll.argocd.tools-k8s-prd.a.intuit.com
    gbranch=prod
    k8snamespace=pts-prod-usw2
    ;;

*) echo "Invalid value, please enter valid value "
esac



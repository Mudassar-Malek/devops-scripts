#!/bin/bash

# echo "Choose your service (JSS PTS ADE): "
svc=$1

# echo "Choose your Environment :- (QA PROD PRF) "
env=$2

# echo "Choose AWS Region :- (USE2 USW2) "
region=$3

# Provide number of replicas
maxreplicas=$4

ws="${svc}-${env}-${region}"

case $ws in 
"jss-qa-usw2") echo "your env is jss-qa-usw2"

    github_url=https://github.intuit.com/payroll-payrolltax/payroll-metrics-deployment.git
    argocdurl=payroll.argocd.tools-k8s-prd.a.intuit.com
    gbranch=environments/qal-usw2-eks 
    k8snamespace=payroll-payrollmetrics-usw2-qal
    ;;

"jss-prod-usw2") echo "your env is jss-prod-usw2"

    github_url=https://github.intuit.com/payroll-payrolltax/payroll-metrics-deployment.git
    argocdurl=payroll.argocd.tools-k8s-prd.a.intuit.com
    gbranch=prod
    k8snamespace=jss-prod-usw2
    ;;

*) echo "Invalid value, please enter valid value "
esac



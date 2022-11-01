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
"payroll-metrics-qal-usw2") echo "your env is payroll-metrics-qal-usw2"

    github_url=github.intuit.com/payroll-payrolltax/payroll-metrics-deployment.git
    argocdurl=payroll.argocd.tools-k8s-prd.a.intuit.com
    gbranch=environments/qal-usw2-eks 
    k8snamespace=payroll-payrollmetrics-usw2-qal
    ;;

"job-schedule-qal-usw2") echo "your env is job-schedule-qal-usw2"

    github_url=https://github.intuit.com/services-jobs/job-schedule-deployment.git
    argocdurl=payroll.argocd.tools-k8s-prd.a.intuit.com
    gbranch=environments/qal-usw2-eks
    k8snamespace=services-jobschedule-usw2-qal
    ;;

*) echo "Invalid value, please enter valid value "
esac



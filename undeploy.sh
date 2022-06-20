#!/usr/bin/env bash
set -a
export VERSION="$1"
export OPERATORDIR="$HOME/operator$VERSION"
export NAMESPACE="awx-namespace"
export STORAGECLASS="set-sc.yaml"
export STORAGECLASSNAME="local-sc"
export PERSISTENTVOL="set-pv.yaml"
export PERSISTENTVOLNAME="local-pv"
export PVPATH="/data/postgres"
export NODEHOSTNAME=$(hostname -s)
export PERSISTENTVOLCLAIM="set-pvc.yaml"
export PERSISTENTVOLCLAIMNAME="postgres-pvc"
export DEPLOYMENT="deploy-awx.yaml"
export LDAP_SECRET_NAME="awx-ipa-ca"
pushd $OPERATORDIR
kubectl delete -f $DEPLOYMENT
kubectl delete $(kubectl get pvc -oname)
kubectl delete -f $PERSISTENTVOL
kubectl delete -f $STORAGECLASS
kubectl delete $LDAP_SECRET_NAME
make undeploy
kubectl -n default delete deployment awx-operator
kubectl -n default delete serviceaccount awx-operator
kubectl -n default delete clusterrolebinding awx-operator
kubectl -n default delete clusterrole awx-operator
echo "To delete $OPERATORDIR press any key."
read
rm -rf $OPERATORDIR
echo "To delete $PVPATH press any key."
read
sudo rm -rf $PVPATH/*

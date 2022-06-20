#!/usr/bin/env bash
# 
# Deploy a specific version of AWX Operator:
# EXAMPLE: bash deploy.sh 0.14.0
# OR run with no argument to get the latest one:
# bash deploy.sh
#
set -a
export VERLIST="$(curl -s https://github.com/ansible/awx-operator/releases| grep -A1 "\"ml-1 wb-break-all\""| grep -v class| grep -v "\-\-"| tr -d " ")"

export VERSION=$( echo -e $VERLIST| awk '{print $1}'| xargs)
echo "Latest version selected: $VERSION"
export OPERATORDIR="$HOME/operator$VERSION"

git clone -b $VERSION https://github.com/ansible/awx-operator.git $OPERATORDIR

export NAMESPACE="awx-namespace"
export NODEIP=$(hostname -i)

pushd $OPERATORDIR
echo
echo " You can edit spread manifests or log into AWX Dashboard now:"
echo
echo "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # "
echo "#"
echo "# You can edit spread manifests or log into AWX Dashboard now:"
echo "# Old resource endpoint: http://$NODEIP:$(kubectl get service -ojson | jq -r '.items[].spec.ports[].nodePort | select( . != null )')/"
echo "# Admin password: $(kubectl get secret awx-admin-password -o go-template='{{range $k,$v := .data}}{{printf "%s: " $k}}{{if not $v}}{{$v}}{{else}}{{$v | base64decode}}{{end}}{{"\n"}}{{end}}')"
echo "#"
echo "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # "
echo " Press any key to proceed... "
read
kubectl config set-context --current --namespace=$NAMESPACE
make deploy

echo -e "Awaiting NEW resources:"
export MGMTPOD=$(kubectl get po| grep manager| awk '{print $1}')
export MGMTCT=$(kubectl get po "$MGMTPOD" -ojson| jq -r '.spec.containers[].name'| grep manager| tail -1)
if [[ $(
	until kubectl logs -f "$MGMTPOD" -c "$MGMTCT" 2>&1| tee| grep -A1 -m1 "PLAY RECAP"; do
            sleep 1; done| grep "failed=0"
    ) ]]; then
    echo -e "Upgrade COMPLETE!"
    echo -e "New deployment succeeded, please check resources:\n"
    kubectl get po,sc,pv,pvc,svc
    echo "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # "
    echo "#"
    echo "# New resource endpoint: http://$NODEIP:$(kubectl get service -ojson | jq -r '.items[].spec.ports[].nodePort | select( . != null )')/"
    echo "# Admin password: $(kubectl get secret awx-admin-password -o go-template='{{range $k,$v := .data}}{{printf "%s: " $k}}{{if not $v}}{{$v}}{{else}}{{$v | base64decode}}{{end}}{{"\n"}}{{end}}')   #"
    echo "#"
    echo "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # "
    echo " Bye-Bye!" 
    exit 0
else
    echo -e "Deployment failed, please check logs."
    exit 1
fi
popd


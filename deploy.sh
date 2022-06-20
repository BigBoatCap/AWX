#!/usr/bin/env bash
# 
# Deploy a specific version of AWX Operator:
# EXAMPLE: bash deploy.sh 0.14.0
# OR run with no argument to get the latest one:
# bash deploy.sh
#
set -a
export VERLIST="$(curl -s https://github.com/ansible/awx-operator/releases| grep -A1 "\"ml-1 wb-break-all\""| grep -v class| grep -v "\-\-"| tr -d " ")"

if [ ! $1 ] || [ "${1,,}" == 'latest' ]; then
	export VERSION=$( echo -e $VERLIST| awk '{print $1}'| xargs)
	echo "Latest version selected: $VERSION"
elif [[ $(echo "$VERLIST"| grep -sx "$1") ]]; then
    export VERSION="$1"
    echo "Selected version: $VERSION"
else
    echo -e " Input version $1 does not exist! \n Please try again. \n Availeble verisons are:\n$VERLIST"
    exit 1
fi

export OPERATORDIR="$HOME/operator$VERSION"

git clone -b $VERSION https://github.com/ansible/awx-operator.git $OPERATORDIR

export LDAP_CA="ldap-ca.crt"
export NAMESPACE="awx-namespace"
export STORAGECLASS="set-sc.yaml"
export STORAGECLASSNAME="local-sc"
export PERSISTENTVOL="set-pv.yaml"
export PERSISTENTVOLNAME="local-pv"
export PVPATH="/data/postgres"
export NODEHOSTNAME=$(hostname -s)
export PERSISTENTVOLCLAIM="set-pvc.yaml"
export PERSISTENTVOLCLAIMNAME="postgres-pvc"
export SECRETS="set-secrets.yaml"
export DEPLOYMENT="deploy-awx.yaml"
export PGSECRETNAME="awx-postgres-configuration"
export AWXSECRET="awxsecret"
export LDAP_SECRET_NAME="awx-ipa-ca"
export PGPASSWORD="abcdotcomL"

pushd $OPERATORDIR
# touch CA secret file for LDAP TLS:
if [[ true ]]; then
    cat > $LDAP_CA << EOF
-----BEGIN CERTIFICATE-----
# PASTE YOUR LDAP CA HERE
-----END CERTIFICATE-----
EOF
fi

# Populate manifests:
if [[ true ]]; then
    cat > $STORAGECLASS << EOF
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: $STORAGECLASSNAME
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF
fi

if [[ true ]]; then
    cat > $PERSISTENTVOL << EOF
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: $PERSISTENTVOLNAME
spec:
  capacity:
    storage: 8Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: $STORAGECLASSNAME
  local:
    path: $PVPATH
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $NODEHOSTNAME
EOF
fi

if [[ true ]]; then
    cat > $PERSISTENTVOLCLAIM << EOF
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $PERSISTENTVOLCLAIMNAME
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: $STORAGECLASSNAME
  resources:
    requests:
      storage: 8Gi
EOF
fi

if [[ true ]]; then
    cat > $SECRETS <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: awx-secret-key
  namespace: $NAMESPACE
stringData:
  secret_key: $AWXSECRET
type: Opaque
---
apiVersion: v1
kind: Secret
metadata:
  name: $PGSECRETNAME
  namespace: $NAMESPACE
stringData:
  host: awx-postgres
  port: "5432"
  database: awx
  username: awx
  password: $PGPASSWORD
  type: managed
type: Opaque
EOF
fi

if [[ true ]]; then
    cat > $DEPLOYMENT <<EOF
---
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx
  namespace: $NAMESPACE
spec:
  service_type: nodeport
  postgres_configuration_secret: $PGSECRETNAME
  ldap_cacert_secret: $LDAP_SECRET_NAME
EOF
fi

echo "You can edit spread manifests now. Press any key to proceed... "
read
kubectl config set-context --current --namespace=$NAMESPACE
make deploy
kubectl apply -f $STORAGECLASS
kubectl patch sc $STORAGECLASSNAME -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl apply -f $PERSISTENTVOL
kubectl apply -f $SECRETS
kubectl create secret generic $LDAP_SECRET_NAME  --from-file="$LDAP_CA"
kubectl apply -f $DEPLOYMENT
# Watch deployment process until nodePort service start up:
until kubectl get svc -w| grep -m1 "awx-service"
do
    sleep 1
done

echo -e "Awaiting resources in about 30 seconds:"
sleep 30
export MGMTPOD=$(kubectl get po| grep manager| awk '{print $1}')
export MGMTCT=$(kubectl get po "$MGMTPOD" -ojson| jq -r '.spec.containers[].name'| grep manager)
if [[ $(
	until kubectl logs -f "$MGMTPOD" -c "$MGMTCT"| tee| grep -A1 -m1 "PLAY RECAP"; do
            sleep 1; done| grep "failed=0"
    ) ]]; then
    echo -e "Deployment succeeded, please check resources:\n"
    kubectl get po,sc,pv,pvc,svc
    echo "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # "
    echo "#"
    echo "# Resource endpoint: http://$(hostname -i):$(kubectl get service -ojson | jq -r '.items[].spec.ports[].nodePort | select( . != null )')/"
    echo "# Admin password: $(kubectl get secret awx-admin-password -o go-template='{{range $k,$v := .data}}{{printf "%s: " $k}}{{if not $v}}{{$v}}{{else}}{{$v | base64decode}}{{end}}{{"\n"}}{{end}}')   #"
    echo "#"
    echo "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # "
    exit 0
else
    echo -e "Deployment failed, please check logs."
    exit 1
fi
popd


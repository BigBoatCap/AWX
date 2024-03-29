# AWX Installation script. Operator-based version.
Many thanks to who did assisted me in digging:
IRC libra.chat: guys from #awx-project 
Google Group: https://groups.google.com/forum/#!forum/awx-project

If you are new then you better start from here: https://github.com/ansible/awx-operator

Presets:
- configure kubectl
- single node
- storage type: local storage
- /data/postgres is claimed by PVC, should be present on the node as well as be owned by root
- suppose we have a Cluster UI https://myrancherinstance.com/dashboard/home    Cluster Name: "awx-k8s"

To deploy a specific version of AWX Operator in Kubernetes cluster:

- If it is for the first time, then we should tune the Cluster.
Edit kubelet config for postgres data directory to be accessible from within pod:
* Don't know why - Directly clicking on Edit Config from main Cluster menu gave me another result ( Rancher 2.5.2 )
 go to UI, _Cluster Management => then 3 dots menu => Edit Config => Edit as Yaml_ and update kubelet manifest like so:

```
    kubelet:
      extra_binds:
        - '/data/postgres:/data/postgres'
```

- add LDAP CA Certificat to deploy.sh
- run __Deploy version script ( operator + awx instance with PV):__

> $ bash deploy.sh 14

Or to __Deploy the latest one:__

> $ bash deploy.sh

... a few minutes later you will see:

```
Resource endpoint: http://10.100.16.104:30080/
Admin password: password: superstrongpassword
```

Q": How to watch deployment process ( kubectl config --set-context --current --namespace=$NAMESPACE ):
_prior_ to operator v. __0.15.0__ ?

A":
```
$ kubectl logs -f deployments/awx-operator-controller-manager -c manager 
```

or for operator v. __0.16.0 and later

```
$ kubectl logs -f deployments/awx-operator-controller-manager -c awx-manager 
```

Q": How to obtain __admin password__ later?

A":
```
$ kubectl get secret awx-admin-password -o go-template='{{range $k,$v := .data}}{{printf "%s: " $k}}{{if not $v}}{{$v}}{{else}}{{$v | base64decode}}{{end}}{{"\n"}}{{end}}'
```

### Migration steps are described here:
Set __Operator__ Replicas to 0:
```
 $ kubectl edit deployment awx-operator-controller-manager
```

set __Awx__ replicas to 0:
```
 $ kubectl edit deployment awx
```

__Recreate DB:__
```
$ kubectl exec -it awx-postgres-0 -- psql -U awx postgres
$ postgres# DROP DATABASE awx;
$ postgres# CREATE DATABASE awx;
$ postgres# \q
$ exit
```

__Import DB Data:__
```
$ kubectl exec -it awx-postgres-0 -- psql -U awx awx < ~/latest.sql
```

set application replicas back to 1 see above
set operator replicas to 1, see above

\# _Watch Operator container logs:
```
kubectl logs -f --since=1m $(kubectl get po| grep manager| awk '{print $1}') -c $(kubectl get po $(kubectl get po| grep manager| awk '{print $1}') -ojson| jq -r '.spec.containers[].name'| grep manager)
```

\# _Watch Task container logs:
```
kubectl logs -f --since=1m $(kubectl get po| grep awx| head -1| awk '{print $1}') -c $(kubectl get po $(kubectl get po| grep awx| head -1| awk '{print $1}') -ojson| jq -r '.spec.containers[].name'| grep task)
```

## __WARNINGS:
! ! ! __Do not use *deploy.sh* script in production__
! ! ! __Do not use *undeploy.sh* script in production__

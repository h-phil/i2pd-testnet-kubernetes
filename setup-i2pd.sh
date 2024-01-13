#!/bin/bash
set -ex

nodes=16
ns="i2pd"
folder="./helm/i2pd-chart"
selector="app.kubernetes.io/name==i2pd-chart"
routerinfo_path="/home/i2pd/data/router.info"

# recreate namespace
kubectl delete namespace $ns --ignore-not-found=true

# deploy helm chart with calico annotation
for i in $(seq $nodes); 
do 
        helm install i2pd-${i} \
        	-f ${folder}/values.yaml \
        	--create-namespace --namespace $ns \
        	--set "podAnnotations.cni\.projectcalico\.org/ipAddrs"="[\"123.8.0.$(($i+1))\"]" \
                $folder; 
done

# wait for all i2pd pods to be ready
kubectl wait pods -n $ns -l $selector --for condition=Ready --timeout=120s

sleep 1

kubectl -n $ns get pods -o wide

sleep 10

# get router info
mkdir -p ${folder}/tmp
pushd ${folder}/tmp
pods=$(kubectl -n $ns get pods -o name --selector $selector)
for p in $pods; do
        num=$(echo $p | cut -d "-" -f 2)
        kubectl -n $ns cp "${p/pod\//}:${routerinfo_path}" "./${num}_router.info"
done
zip seed.zip *_router.info
popd
cp ${folder}/tmp/seed.zip $folder

# delete all containers
kubectl -n $ns delete pods,deployments,replicasets -l $selector

# deploy again
for i in $(seq $nodes); 
do 
        helm upgrade i2pd-${i} \
        	-f ${folder}/values.yaml \
                --create-namespace --namespace $ns \
                --set "podAnnotations.cni\.projectcalico\.org/ipAddrs"="[\"123.8.0.$(($i+1))\"]" \
                $folder; 
done

# cleanup
rm -rf ${folder}/tmp
rm -f ${folder}/seed.zip

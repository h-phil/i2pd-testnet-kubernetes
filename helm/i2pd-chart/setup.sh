#!/bin/bash
set -ex

ns="i2pd"
nodes=16
selector="app.kubernetes.io/name==i2pd-chart"
routerinfo_path="/home/i2pd/data/router.info"

# recreate namespace
kubectl delete namespace $ns --ignore-not-found=true

# deploy helm chart with calico annotation
for i in $(seq $nodes); do helm install i2pd-$i -f values.yaml --create-namespace --namespace $ns --set "podAnnotations.cni\.projectcalico\.org/ipAddrs"="[\"10.8.0.$(($i+1))\"]" ./; done

# wait for all i2pd pods to be ready
kubectl wait pods -n $ns -l $selector --for condition=Ready --timeout=120s

sleep 1

kubectl -n $ns get pods -o wide

sleep 10

# get router info
mkdir -p tmp
pushd tmp

pods=$(kubectl -n $ns get pods -o name --selector $selector)
for p in $pods; do
        num=$(echo $p | cut -d "-" -f 2)
        kubectl -n $ns cp "${p/pod\//}:${routerinfo_path}" "./${num}_router.info"
done

zip seed.zip *_router.info
popd
cp tmp/seed.zip ./

# delete all containers
kubectl -n $ns delete pods,deployments,replicasets --all

# deploy again
for i in $(seq $nodes); do helm upgrade i2pd-$i -f values.yaml --create-namespace --namespace $ns --set "podAnnotations.cni\.projectcalico\.org/ipAddrs"="[\"10.8.0.$(($i+1))\"]" ./; done


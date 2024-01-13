#!/bin/bash
set -ex

nodes=16
ns="i2p"
folder="./helm/i2p-chart"
selector="app.kubernetes.io/name==i2p-chart"
routerinfo_path="/i2p/.i2p/router.info"
#lb_ip="127.0.0.1"
lb_ip="192.168.1.60"

# recreate namespace
kubectl delete namespace $ns --ignore-not-found=true

# deploy helm chart with calico annotation
for i in $(seq $nodes); 
do 
        ip="123.8.0.$(($i+1))"
        helm install i2p-${i} \
        	-f ${folder}/values.yaml \
        	--create-namespace --namespace $ns \
        	--set "podAnnotations.cni\.projectcalico\.org/ipAddrs"="[\"${ip}\"]" \
                --set "i2p.ip=${ip}" \
                $folder; 
done

# wait for all i2pd pods to be ready
kubectl wait pods -n $ns -l $selector --for condition=Ready --timeout=120s

sleep 1

kubectl -n $ns get pods -o wide

echo "waiting 60s for the routers to start properly before attempting to reseed"
sleep 60

# get router info
mkdir -p ${folder}/tmp
pushd ${folder}/tmp
pods=$(kubectl -n $ns get pods -o name --selector $selector)
for p in $pods; do
        num=$(echo $p | cut -d "-" -f 2)
        # files need to have a special name / length
       	# https://github.com/i2p/i2p.i2p/blob/ea8b3f00c0b5908b0c8207653e08a23c63f131c7/router/java/src/net/i2p/router/networkdb/reseed/Reseeder.java#L907
        prefixednum=$(printf "%044d" $num)
	name="routerInfo-${prefixednum}.dat"
        kubectl -n $ns cp "${p/pod\//}:${routerinfo_path}" "./${name}"
done
zip seed.zip routerInfo-*.dat
popd
cp ${folder}/tmp/seed.zip ./

# reseed via console
nodeports=$(kubectl -n $ns get svc -l "component==i2p-console" -o=jsonpath='{.items[*].spec.ports[*].nodePort}')
for p in $nodeports;
do
        url="http://${lb_ip}:${p}/configreseed"
        curl -s -o /dev/null -w "HTTP %{http_code} \n" -f -X POST -F file='@seed.zip' $url 
done

## delete all containers
#kubectl -n $ns delete pods,deployments,replicasets -l $selector
#
## deploy again
#for i in $(seq $nodes); 
#do 
#        helm upgrade i2p-${i} \
#        	-f ${folder}/values.yaml \
#                --create-namespace --namespace $ns \
#                --set "podAnnotations.cni\.projectcalico\.org/ipAddrs"="[\"123.8.0.$(($i+1))\"]" \
#                $folder; 
#done

# cleanup
rm -rf ${folder}/tmp
#rm -f seed.zip

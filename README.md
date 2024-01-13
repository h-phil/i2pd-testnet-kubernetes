# I2PD Test Network in Kubernetes

![Traffic](./traffic.png)

This is a prototype deployment of an I2P test network using i2pd on k3s. 
To properly reseed the routers, calico with static IPs is used as CNI.

## Prerequisites

1. GNU/Linux system for our k3s cluster 
  - 4 Cores and 8 GB RAM or more are recommended (depending on how many routers you want to deploy)
  - system needs internet connectivity for the initial setup and for Kubernetes to pull the i2pd container images
  - I do not recommend to expose this node directly to the internet!
  - For further information see the k3s requirements: https://docs.k3s.io/installation/requirements

2. Command Line tools
  - Install `kubectl` (https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
  - Install `helm` (https://helm.sh/docs/intro/install/)
  - Install `calicoctl` (https://docs.tigera.io/calico/latest/operations/calicoctl/install)

## Setup K3S

### Single-node K3S Cluster with Calico
> For an up-to-date version check the calico docs: https://docs.tigera.io/calico/latest/getting-started/kubernetes/k3s/quickstart

```bash
# k3s install without default flannel
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="--flannel-backend=none --cluster-cidr=10.4.0.0/16 --disable-network-policy --disable=traefik" sh -

# get kube config for kubectl
mkdir ~/.kube
sudo k3s kubectl config view --raw | tee ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config
echo "export KUBECONFIG=~/.kube/config" >> .bashrc

# show k3s nodes
# you should see one k3s node with the status "READY"
kubectl get nodes -o wide 

# install calico
#
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/custom-resources.yaml

# wait until all pods are ready
watch kubectl get pods --all-namespaces
```

### Configure Calico IP pool

To assign static IPs to our routers we need to create a calico `IPPool`.
In this case we use a `nodeSelector` that matches nothing per default and we have to manually assign the IPs using a `podAnnotation`. (see [setup.sh](/helm/i2pd-chart/setup.sh))

Config:

```yaml
# test-pool.yaml
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: test-pool
spec:
  cidr: 10.8.0.0/16
  natOutgoing: true
  disabled: false
  nodeSelector: "!all()"
```

Apply the config:

```bash
# apply new pool
calicoctl apply -f test-pool.yaml

# get pools
calicoctl get ippools
```

# Setup Test Network

The setup consists of three steps. 
- At first we deploy our i2pd routers without reesed information via `helm install`. During the install we have to set a podAnnotation for calico to assign a static IP address to the i2pd pods.
- Once all pods have been started and are ready, we can copy the newly generated router.info files from each of the pods, zip them and save them as `seed.zip` in the local directory.
- After the zipfile has been generated we need to kill all containers and upgrade the deployment via `helm upgrade`.
The `seed.zip` is automatically mounted via a configmap to all pods.

See [setup.sh](/helm/i2pd-chart/setup.sh)

## Usage 

```bash
cd helm/i2pd-chart
./setup.sh
```

# FAQ

## Where is the i2pd.conf?

i2pd.conf is inside the helm values.

```yaml
...
config: |
    log = stdout
    loglevel = debug
    ...
```

See the helm values.yaml [here](./helm/i2pd-chart/values.yaml)

## What container image is used? 

The relative image name is configured inside the helm values.
K3s uses dockerhub per default for relative image names.

```yaml
...
image:
  repository: purplei2p/i2pd
  pullPolicy: IfNotPresent
  # Overrides the image tag whose default is the chart appVersion.
  tag: latest
...
```

See the helm values.yaml [here](./helm/i2pd-chart/values.yaml)

## How can I capture I2P-Traffic?

You can do a simple `tcpdump` on the k3s node.

```bash
k3s-node$ sudo tcpdump -nnni any net "123.8.0.0/16" -w traffic.pcap
```

## How can I change the network latency / packet loss between the i2pd routers?

You can change the network latency and packet loss in the [values.yaml](./helm/i2pd-chart/values.yaml).
The `tc` command is run in every pod before the i2pd container is started.

```yaml
trafficControl:
  enabled: true
  image:
    # see https://github.com/h-phil/alpine-iproute2
    repository: hphil/alpine-iproute2
    tag: latest
  init: |
    #!/bin/sh
    set -ex
    # delay of 40+-20ms (normal distribution) per pod
    # 0.1% loss with higher successive probablity (packet burst lossess)
    tc qdisc add dev eth0 root netem delay 40ms 20ms distribution normal loss 0.1% 25%
```

You can disable this if you set `enabled` to `false`.

# Other links/resources

Some other test networks that use a similar concept but didn't work for me:

- https://web.archive.org/web/20230129074448/https://0xcc.re/2018/10/16/howto-run-128-i2p-routers-in-multiple-subnets-on-a-single-linux-system.html
- https://github.com/l-n-s/testnet.py
- https://github.com/l-n-s/docker-testnet


# I2PD Test Network in Kubernetes

This is a prototype deployment of an I2P test network using i2pd on k3s. As both i2p.i2p and i2pd prevent routers from talking to private range IPs, we need calico to assign static IPs to containers.

## Prerequisites

1. GNU/Linux system for our k3s cluster 
  - 4 Cores and 8 GB RAM or more are recommended (depending on how many routers you want to deploy)
  - system needs internet connectivity for the initial setup and for kubernetes to pull the i2pd container images
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

As mentioned above we need to make the I2P routers think they have a public IP.
For this we use calico to create a custom IP pool.

Config:

```yaml
# test-pool.yaml
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: public-test-pool
spec:
  cidr: 123.8.0.0/16
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

See [setup.sh](,/helm/i2pd-chart/setup.sh)

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


## Why did you not disable the i2pd `reservedrange` check?

Disabling it still causes issues with reseeding and tunnel creation.
Unclear what the exact impact of the [reserverange](https://github.com/PurpleI2P/i2pd/blob/fb420bb563a3ebf8803faaa390ba6b2bb840d872/daemon/Daemon.cpp#L301C49-L301C62) option is.

## How can I capture I2P-Traffic?

You can do a simple `tcpdump` on the k3s node.

```bash
k3s-node$ sudo tcpdump -nnni any net "123.8.0.0/16" -w traffic.pcap
```

# Other links/resources

Some other test networks that use a similar concept but didn't work for me:

- https://web.archive.org/web/20230129074448/https://0xcc.re/2018/10/16/howto-run-128-i2p-routers-in-multiple-subnets-on-a-single-linux-system.html
- https://github.com/l-n-s/testnet.py
- https://github.com/l-n-s/docker-testnet


# I2PD Test Network in Kubernetes

This is a prototype deployment of an I2P testnet using i2pd on k3s. As both i2p.i2p and i2pd prevent routers from talking to private range IPs, we need calico to assign static IPs to containers.

## Prerequisites

1. GNU/Linux system for our k3s cluster 
  - 4 Cores and 8 GB RAM or more are recommended
  - for further information see k3s requirements: https://docs.k3s.io/installation/requirements
  - system needs internet connectivity for the initial setup and for kubernetes to pull the i2pd container images
  - I do not recommend to expose this node directly to the internet!

2. Command Line tools
  - Install `kubectl` (https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
  - Install `helm` (https://helm.sh/docs/intro/install/)
  - Install `calicoctl` (https://docs.tigera.io/calico/latest/operations/calicoctl/install)

## Setup K3S

### Single-node k3s cluster with calico
> see calico doc: https://docs.tigera.io/calico/latest/getting-started/kubernetes/k3s/quickstart

```bash
# k3s install without default flannel
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="--flannel-backend=none --cluster-cidr=10.4.0.0/16 --disable-network-policy --disable=traefik" sh -

# get kube config for kubectl
mkdir ~/.kube
sudo k3s kubectl config view --raw | tee ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config
echo "export KUBECONFIG=~/.kube/config" >> .bashrc

# Show k3s nodes
kubectl get nodes -o wide 
# you should see one k3s node with the status "READY"
```

### Configure Calico IP pool

As mentioned above we need make the I2P routers think have a public IP.
For this we use calico to create a custom ip pool.

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

```bash
cd helm/i2pd-chart
./setup.sh
```

# Other links/resources
- https://web.archive.org/web/20230129074448/https://0xcc.re/2018/10/16/howto-run-128-i2p-routers-in-multiple-subnets-on-a-single-linux-system.html
- https://github.com/l-n-s/testnet.py
- https://github.com/l-n-s/docker-testnet


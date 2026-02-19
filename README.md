# <a name="MalcolmHelm"></a>Malcolm Helm Chart

The purpose of this project is to facilitate installing [Malcolm](https://github.com/idaholab/Malcolm/), with all of its server and sensor components, across a Kubernetes cluster.

For more information on Malcolm and its features, see:

* [Malcolm documentation](https://idaholab.github.io/Malcolm/)
* [Malcolm learning tree](https://github.com/cisagov/Malcolm/wiki/Learning)
* [Malcolm training tutorial videos](https://www.youtube.com/@malcolmnetworktrafficanalysis/videos)

### <a name="TableOfContents"></a>Table of Contents

* [Installation From Helm Repository](#HelmRepoQuickstart)
* [Demonstration Using Vagrant](#VagrantDemo)
    - [Vagrant Quickstart (without Istio)](#VagrantQuickstart)
    - [Vagrant Quickstart (with Istio)](#VagrantQuickstartIstio)
    - [Listener NIC Setup](#NICSetup)
* [Production Cluster Requirements](#ProductionReqs)
* [Label requirements](#Labels)
* [External Elasticsearch notes](#ElasticNodes)
* [Storage Provisioner Options](#StorageProvisioner)
    - [Configure an NFS server](#NFSServer)
    - [Install the nfs-client on all Kubernetes nodes](#NFSClient)
    - [Install the nfs-subdir-external-provisioner](#NFSProvisioner)
    - [Test the newly installed nfs-subdir-external-provisioner](#NFSTest)
    - [Configure Malcolm-Helm to use the nfs-subdir-external-provisioner](#NFSMalcolmConfig)
* [Updating Malcolm-Helm for a New Malcolm Release](#HelmChartUpdate)

## <a name="HelmRepoQuickstart"></a>Installation From Helm Repository

Ensure you understand the [Production Cluster Requirements](#ProductionReqs) and [Label Requirements](#Labels) before proceeding.

* Add the repository:

```bash
$ helm repo add malcolm \
    https://raw.githubusercontent.com/idaholab/Malcolm-Helm/refs/heads/helm-repo/
"malcolm" has been added to your repositories

$ helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "malcolm" chart repository
Update Complete. ⎈Happy Helming!⎈

$ helm search repo malcolm
NAME               CHART VERSION   APP VERSION DESCRIPTION                                     
malcolm/malcolm    25.11.0         25.11.0     A Helm chart for Deploying Malcolm in Kubernetes
```

* Optionally, create [`values.yaml`](./chart/values.yaml) to review and modify as necessary:

```bash
$ helm show values malcolm/malcolm > values.yaml
$ vi ./values.yaml
…
```

* Deploy the Helm chart to the cluster:

```bash
$ export MALCOLM_NAMESPACE=malcolm

$ kubectl create namespace $MALCOLM_NAMESPACE
namespace/malcolm created

$ ( command -v openssl >/dev/null 2>/dev/null && command -v htpasswd >/dev/null 2>/dev/null ) && \
    kubectl create secret generic -n $MALCOLM_NAMESPACE malcolm-auth \
        --from-literal=username="johndoe" \
        --from-literal=openssl_password="$(openssl passwd -1 'SuperSecretPassword' | tr -d '\n' | base64 | tr -d '\n')" \
        --from-literal=htpass_cred="$(htpasswd -bnB 'johndoe' 'SuperSecretPassword' | head -n1)" || \
    echo "openssl and htpasswd are needed to create password hashes" >&2
secret/malcolm-auth created

# Use `--values ./values.yaml` if it was created in the previous step.
# Specify value overrides with `--set` as needed.
# For example:
$ helm install malcolm malcolm/malcolm \
    --values ./values.yaml \
    --namespace $MALCOLM_NAMESPACE \
    --set is_production=true \
    --set auth.existingSecret=malcolm-auth \
    --set istio.enabled=true \
    --set ingress.enabled=false \
    --set pcap_capture_env.pcap_iface=eth0
NAME: malcolm
LAST DEPLOYED: Wed Nov 12 14:20:18 2025
NAMESPACE: malcolm
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

## <a name="VagrantDemo"></a>Demonstration Using Vagrant

For the purposes of demonstration, this repository contains a Vagrantfile for quick creation of a virtualized single-node Kubernetes installation with the Malcolm Helm chart installed.

It is [required](https://idaholab.github.io/Malcolm/docs/system-requirements.html#SystemRequirements) that the host system has at least 8 CPU cores, 16 GB of RAM and as much available storage as necessary for the amount of PCAP retention desired (at least 100GB). The virtual machine's resources and other configuration options can be overriden via the following environment variables:

* `VAGRANT_SETUP_CHOICE` - `use_istio` to use the Istio service mesh, otherwise the RKE2 ingress is used
* `VAGRANT_BOX` - the base VM image for Vagrant to use (default `bento/debian-13`)
* `VAGRANT_CPUS` - the number of CPU cores for the virtual machine (default `8`)
* `VAGRANT_MEMORY` - the megabytes of RAM for the virtual machine (default `24576`)
* `VAGRANT_DISK_SIZE` - the maximum size of the virtual machine's storage (default `400GB`)
* `VAGRANT_NAME` - the name of the virtual machine (default `Malcolm-Helm`)
* `VAGRANT_GUI` - set to `true` to open the virtual machine manager's user interface (default `true`)
* `VAGRANT_SSD` - set to `true` to mark the virtual machine's storage as nonrotational (default `true`)
* `VAGRANT_NIC` - the name of the NIC as visible to the virtual machine's operating system (default `enp0s8`)
* `MALCOLM_NAMESPACE` - the Kubernetes namespace to create (default `malcolm`)
* `MALCOLM_USERNAME` - the username to use for Malcolm authentication for HTTP basic auth (default `malcolm`)
* `MALCOLM_PASSWORD` - the password to use for Malcolm authentication for HTTP basic auth (default `malcolm`)

The credentials from the `MALCOLM_USERNAME` and `MALCOLM_PASSWORD` variables are stored in a Kubernetes secret created thusly:

```bash
kubectl create secret generic -n malcolm malcolm-auth \
    --from-literal=username="johndoe" \
    --from-literal=openssl_password="$(openssl passwd -1 'SuperSecretPassword' | tr -d '\n' | base64 | tr -d '\n')" \
    --from-literal=htpass_cred="$(htpasswd -bnB 'johndoe' 'SuperSecretPassword' | head -n1)"
```

which is then indicated to the `helm install` command with `--set auth.existingSecret=malcolm-auth`.

### <a name="VagrantQuickstart"></a>Vagrant Quickstart (without Istio)

1. [Download](https://www.virtualbox.org/wiki/Downloads) and install VirtualBox (virt-manager or VMware are also options)
2. [Download](https://developer.hashicorp.com/vagrant/downloads) and install Vagrant
3. Install required Vagrant plugins:
    * `vagrant plugin install vagrant-disksize`
    * `vagrant plugin install vagrant-reload`
4. `cd /path/to/Malcolm-Helm`
5. `vagrant up`
6. Wait for installation to complete (signaled by the "You may now ssh to your kubernetes cluster..." message)
7. Open a web browser and navigate to `http://localhost:8080` to display the Malcolm landing page.
    * The default username/password is `malcolm`/`malcolm`, although it is preferred that users set their own credentials in the `MALCOLM_USERNAME` and `MALCOLM_PASSWORD` environment variables as described [above](VagrantDemo)
    * It may take several minutes for all Malcolm's services to become available.
8. If desired, SSH into the VM with `ssh -p 2222 vagrant@localhost` and the password `vagrant`

### <a name="VagrantQuickstartIstio"></a>Vagrant Quickstart (with Istio)

To configure Kubernetes to use the Istio service mesh instead of using RKE2 ingress, follow the **Vagrant Quickstart** steps with the following adjustments:

* Run `VAGRANT_SETUP_CHOICE=use_istio vagrant up` (rather than `vagrant up`) to bring up the virtual machine
* With elevated privileges, edit the system `hosts` file (`/etc/hosts` for Linux, `C:\Windows\System32\drivers\etc\hosts` for Windows) and add:
    - `127.0.0.1 localhost malcolm.vp.bigbang.dev`
* Malcolm will be accessible at `https://malcolm.vp.bigbang.dev:8443`
    - If prompted with "Your connection is not private", either add the self-signed certificates to the browser's trusted store or, if using Chrome, click anywhere on the error page and type `thisisunsafe`.

### <a name="NICSetup"></a>Listener NIC Setup

For the Malcolm-Helm VM to be able to inspect network traffic on its virtual NIC it must be set to "promiscuous mode." Steps for doing this varies depending on the virtualization platform, but for VirtualBox:

1. Open VirtualBox
2. Right click the Malcolm-Helm VM and select **Settings**
3. Select **Network** from the menu on the left
4. Select the `Adapter 2` tab
5. Change **Attached** to `Bridged Adapter`
6. Select the **Advanced** drop down
7. Ensure promiscuous mode is set to `Allow all` 
8. Verify promiscuous mode is enabled
    * SSH into the VM with `ssh -p 2222 vagrant@localhost` and the password `vagrant`
    * run `tcpdump -i enp0s8` (or whatever the VM's NIC is) to ensure traffic is seen on the interface

## <a name="ProductionReqs"></a>Production Cluster Requirements

For larger-scale production environments, the following requirements should be satisfied prior to installing the Helm chart. Other configurations may work but have not been tested.

* Kubernetes RKE2 installation (`v1.24.10+rke2r1` has been tested)
* Storage class that is capable of handling `ReadWriteMany` volumes across all Kubernetes nodes (e.g., Longhorn) 
* Storage class that is built for local / fast storage for the statefulsets
  * TODO: still need to convert OpenSearch to statefulset as well as postgreSQL for NetBox
* [Istio service mesh](https://istio.io/latest/docs/setup/getting-started)

### <a name="Labels"></a>Label requirements

All primary server nodes should be labeled with `kubectl label nodes <node-name> cnaps.io/node-type=Tier-1`. Failure to do so will result in certain services (e.g., Logstash) not being provisioned.

All sensor nodes should be labeled with one or more of the following:

* `kubectl label nodes <node-name> cnaps.io/arkime-capture=true` 
* `kubectl label nodes <node-name> cnaps.io/suricata-capture=true` 
* `kubectl label nodes <node-name> cnaps.io/zeek-capture=true`
* `kubectl label nodes <node-name> cnaps.io/zeek-remote-capture=true`

Failure to add any of these labels will result in traffic capture pods not being provisioned on those nodes.

The [Vagrant demonstration](#VagrantDemo) above handles and applies all these labels automatically.

## <a name="ElasticNodes"></a>External Elasticsearch notes

Elasticsearch requires TLS termination in order for it to support Single Sign On (SSO) functionality. The values file was updated to give the user of this Helm chart the ability to copy the certificate file from a different namespace into Malcolm namespace for usage.

Furthermore, the Kibana interface (specified via `dashboards_url`) is still expected to remain unencrypted when using Istio service mesh.

## <a name="StorageProvisioner"></a>Storage Provisioner Options

Malcolm-Helm's `chart/values.yaml` file defaults to the Rancher [local-path](https://github.com/rancher/local-path-provisioner) storage provisioner which allocates storage from the Kubernetes nodes' local storage. As stated [above](#ProductionReqs), any storage provider that supports the `ReadWriteMany` access mode may be employed for Malcolm-Helm. This section provides an example of how to configure the [nfs-subdir-external-provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner) for enviroments with an NFS server available.

### <a name="NFSServer"></a>Configure an NFS server

[nfs-subdir-external-provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner) relies on an external NFS server to provide Kubernetes PersistentVolumes. The first step is to install an NFS server where the Kuberentes cluster can access the NFS shared volumes. For Debian-based systems (including Ubuntu) [this page](https://documentation.ubuntu.com/server/how-to/networking/install-nfs/index.html) details steps to install an NFS server with `apt`:

```bash
sudo apt install nfs-kernel-server
sudo systemctl start nfs-kernel-server.service
```

With the NFS service installed and running, a directory must be exported for use by the Kubernetes provisioner. In this example a directory is exported for the nfs-subdir-provisioner by first creating a folder structure on the server's local filesystem, then add that path to `/etc/exports` on the NFS server. To verify everything works properly, this example will start with fully open directory permissions.

```bash
sudo mkdir -p /exports/malcolm/nfs-subdir-provisioner
sudo chown nobody:nogroup /exports
sudo chmod -R 777 /exports/malcolm/nfs-subdir-provisioner/
```

Add a new line to the NFS server's `/etc/exports` with the base path of our newly created `/exports` directory and an optional network subnet filter. In the following example NFS access is limited to IP addresses within the `10.0.0.0/16` subnet. This can also be replaced with an asterisk `*` symbol to disable subnet filtering.

```
/exports 10.0.0.0/255.255.0.0(rw,sync,insecure,no_root_squash,no_subtree_check,crossmnt)
```

Finally, apply the NFS configuration changes with the `exportfs` command:

```bash
$ sudo exportfs -av
exporting 10.0.0.0/255.255.0.0:/exports
```

Verify the exported directory by querying the NFS server with `showmount`.

```bash
$ usr/sbin/showmount -e nfsserver.example.org
Export list for nfsserver.example.org:
/exports 10.0.0.0/255.255.0.0
```

Make note of the NFS server's IP address or DNS name and the exported path for use in the next steps.

### <a name="NFSClient"></a>Install the nfs-client on all Kubernetes nodes

Since the Kubernetes pods will be making use of the NFS server export and the pods may run on any Kubernetes node, the NFS client must be installed on each node. Connect to each machine and run the following commands:

```bash
sudo apt update
sudo apt install nfs-common -y
```

### <a name="NFSProvisioner"></a>Install the nfs-subdir-external-provisioner

The [nfs-subdir-exeternal-provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner) can be installed via [via Helm](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner?tab=readme-ov-file#with-helm) (as demonstrated below), with Kustomize, or manually via a set of YAML manifests.

These steps require the NFS server's IP address or DNS host name as well as the NFS exported path from [above](#NFSServer). In the following example the server's DNS name is `nfsserver.example.org` and the exported path on that server is `/exports/malcolm/nfs-subdir-provisioner`. Note that although the NFS server's export path is actually `/exports`, the nfs-subdir-external-provisioner can point to a sub-directory within the exported path (e.g., `/exports/malcolm/nfs-subdir-provisioner`) to keep the files created by Malcolm contained to that directory.

Add the Helm repo, then install the provisioner, minimally with the `nfs.server` and `nfs.path` parameters. Other user-configurable options are also noted here by superscript (ᵃ, ᵇ, etc.). See the key beneath the example.
 
```bash
$ helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
$ helm install nfs-subdir-external-provisionerᵃ nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    -n defaultᵇ \
    --set nfs.server=nfsserver.example.orgᶜ \
    --set nfs.path=/exports/malcolm/nfs-subdir-provisionerᵈ \
    --set storageClass.name=nfs-clientᵉ \
    --set storageClass.provisionerName=cluster.local/nfs-subdir-external-provisionerᶠ \
    --set fullnameOverride=nfs-subdir-external-provisionerᵍ
```

**Key:**

* a - **Release name** (must be unique within the namespace)
* b - **Namespace** into which the provisioner will be installed
* c - **NFS server** hostname/IP hosting the export (**required**)
* d - **NFS export path** on the server (base directory under which subdirectories/PVs will be created) (**required**)
* e - **StorageClass name** that will be created ([to be specified as](#NFSMalcolmConfig) `storage_class_name` in `values.yaml`)
* f - **Provisioner name/ID** for this instance (must be unique cluster-wide if you run multiple provisioners)
* g - **fullnameOverride** for Kubernetes object naming (useful to avoid name collisions / make resources easier to identify)

Ensure the storage class was successfully deployed:

```bash
$ kubectl get sc -A
NAME                   PROVISIONER                                     RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
nfs-client             cluster.local/nfs-subdir-external-provisioner   Delete          Immediate              true                   16s
```

A new `nfs-subdir-external-provisioner` should be running in the default namespace:

```bash
$ kubectl get pods -A
NAMESPACE       NAME                                               READYs   STATUS              RESTARTS      AGE
default         nfs-subdir-external-provisioner-7ff748465c-ssf7s   1/1     Running             0             32s
```

### <a name="NFSTest"></a>Test the newly installed nfs-subdir-external-provisioner

Two YAML files are needed to test the provisioner configuration. The [first](https://raw.githubusercontent.com/kubernetes-sigs/nfs-subdir-external-provisioner/master/deploy/test-claim.yaml) defines a PersistentVolumeClaim that leverages the nfs-subdir-external-provisioner.

```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: test-claim
spec:
  storageClassName: nfs-client
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Mi
```

Note that `storageClassName` is set to `nfs-client` which matches the output of the `kubectl get sc -A` command above.

 
The other [test file](https://raw.githubusercontent.com/kubernetes-sigs/nfs-subdir-external-provisioner/master/deploy/test-pod.yaml) defines a pod to make use of the newly created PersistentVolumeClaim.

```yaml
kind: Pod
apiVersion: v1
metadata:
  name: test-pod
spec:
  containers:
  - name: test-pod
    image: busybox:stable
    command:
      - "/bin/sh"
    args:
      - "-c"
      - "touch /mnt/SUCCESS && exit 0 || exit 1"
    volumeMounts:
      - name: nfs-pvc
        mountPath: "/mnt"
  restartPolicy: "Never"
  volumes:
    - name: nfs-pvc
      persistentVolumeClaim:
        claimName: test-claim
```

This pod definition lists `test-claim` in the `volumes:` section at the bottom of the file which matches the PersistentVolumeClaim's `name` field above and ties the two together.

Both of these test files are avalabile as part of the nfs-subdir-external-provisioner source code and can be deployed directly from GitHub:

```bash
$ kubectl create \
  -f https://raw.githubusercontent.com/kubernetes-sigs/nfs-subdir-external-provisioner/master/deploy/test-claim.yaml \
  -f https://raw.githubusercontent.com/kubernetes-sigs/nfs-subdir-external-provisioner/master/deploy/test-pod.yaml
persistentvolumeclaim/test-claim created
pod/test-pod created
```

Verify the PersistentVolumeClaim was created and has a status of `Bound`:

```bash
$ kubectl get pvc
NAME         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
test-claim   Bound    pvc-49649079-ffc5-402e-a6da-b3be50978e02   1Mi        RWX            nfs-client     <unset>                 100s
```

Test that the pod is running:

```bash
$ kubectl get pods -n default
NAME                                               READY   STATUS      RESTARTS   AGE
nfs-subdir-external-provisioner-7ff748465c-q5hbl   1/1     Running     0          27d
test-pod                                           0/1     Completed   0          7m31s
```

The PerstentVolumeClaim should make a new directory in the NFS export and the pod is designed to exit after creating a `SUCCESS` file in that directory. `test-pod` shows a status of `Completed` because the pod already started, created the file, and exited. Check the NFS directory to verify a new directory has been created and it contains a file named `SUCCESS`.

```bash
$ ls -al
total 0
drwxrwxrwx  3 1000  1000  81 Jan 15 09:58 .
drwxrwxrwx 10 1000  1000 213 Jan 18 08:02 ..
drwxrwxrwx  2 root  root  21 Jan 15 09:58 default-test-claim-pvc-20de4d0b-3e1c-4e7b-83c9-d6915a483328
```

The directory should contain one file which was created when the pod started:

```bash
$ ls default-test-claim-pvc-20de4d0b-3e1c-4e7b-83c9-d6915a483328
SUCCESS
```

Delete the pod and the PersistentVolumeClaim using the same YAML files used to create them:

```bash
$ kubectl delete \
  -f https://raw.githubusercontent.com/kubernetes-sigs/nfs-subdir-external-provisioner/master/deploy/test-claim.yaml \
  -f https://raw.githubusercontent.com/kubernetes-sigs/nfs-subdir-external-provisioner/master/deploy/test-pod.yaml
persistentvolumeclaim "test-claim" deleted
pod "test-pod" deleted
```

The NFS directory will be renamed as `archived-default-test-claim-pvc...` and can be manually deleted.

```bash
rm -rf archived-default-test-claim-pvc-20de4d0b-3e1c-4e7b-83c9-d6915a483328/
```

### <a name="NFSMalcolmConfig"></a>Configure Malcolm-Helm to use the nfs-subdir-external-provisioner

With the NFS server exports configured correctly and the Kubernetes nfs-subdir-external-provisioner able to access them for PersistentVolumeClaims, Malcolm-Helm is ready to be configured for deployment. As stated [above](#StorageProvisioner), the Malcolm-Helm [`values.yaml` file](https://github.com/idaholab/Malcolm-Helm/blob/main/chart/values.yaml) defaults to the Rancher [local-path](https://github.com/rancher/local-path-provisioner) storage provisioner. This is defined at the top of `values.yaml` by `storage_class_name`, which can be changed to `nfs-client` to leverage the `nfs-subpath-external-provisioner` and the NFS server exports:

```yaml
# The StorageClass used for persistent volumes. Defaults to `local-path` (Local Path Provisioner).
# If your cluster doesn't support this, set `storage_class_name` to another class that supports
# ReadWriteMany. You can also override it at install time, e.g.:
#    helm install --set "storage_class_name=nfs-client"
storage_class_name: nfs-client
```

If further customization were needed -- for example, using different storage classes for different claims -- it could be accomplished by overriding the individual claims with `classNameOverride` in the `storage` section of `values.yaml`.

Now, follow the [Installation procedures](#installation-procedures) section above to deploy the Malcolm-Helm chart into your cluser.

```bash
$ cd /path/to/Malcolm-Helm
$ helm install malcolm chart/ -n malcolm --create-namespace
NAME: malcolm
LAST DEPLOYED: Tue Jul 15 13:35:51 2025
NAMESPACE: malcolm
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

The Malcolm-Helm pods should all be `Running` after a few minutes:

```bash
$ kubectl get pods -n malcolm
NAME                                           READY   STATUS    RESTARTS AGE
api-deployment-ccd48474-9gnwl                  1/1     Running   0        46s
arkime-deployment-7f5dc4fcd8-t24vn             1/1     Running   0        47s
dashboards-deployment-6f9c4c6d7d-t9lpn         1/1     Running   0        45s
dashboards-helper-deployment-7bc86896c-nxbvp   1/1     Running   0        47s
filebeat-offline-deployment-68b9d6dd5f-ghjm8   1/1     Running   0        46s
filescan-deployment-8cf9c7595-kh8xw            1/1     Running   0        47s
freq-deployment-7d8dd4d88b-jdkkv               1/1     Running   0        47s
htadmin-deployment-55d89f4967-f46l7            1/1     Running   0        47s
logstash-deployment-6479dbd4c9-bmvrq           1/1     Running   0        45s
logstash-deployment-6479dbd4c9-pq5wg           1/1     Running   0        46s
logstash-deployment-6479dbd4c9-px56c           1/1     Running   0        45s
logstash-deployment-6479dbd4c9-vccc7           1/1     Running   0        45s
netbox-deployment-58d7b6bf9f-dtpd6             1/1     Running   0        47s
nginx-proxy-deployment-77c9cfc9cc-7wjt4        1/1     Running   0        47s
opensearch-0                                   1/1     Running   0        47s
pcap-monitor-deployment-5ddffb999f-g5wsx       1/1     Running   0        47s
postgres-statefulset-0                         1/1     Running   0        47s
redis-cache-deployment-86b95b5c75-hnn9b        1/1     Running   0        47s
redis-deployment-659ffb44b6-krtv9              1/1     Running   0        47s
strelka-backend-deployment-588b8d6bd9-bgplg    1/1     Running   0        47s
strelka-frontend-deployment-7fddf7989c-sdsr7   1/1     Running   0        45s
strelka-manager-deployment-6bb9d67d97-lpd4q    1/1     Running   0        46s
suricata-offline-deployment-85654c77df-9ps6x   1/1     Running   0        45s
upload-deployment-795dd4998f-qdvl8             1/1     Running   0        45s
zeek-offline-deployment-5c76b6f9bd-v98bt       1/1     Running   0        46s
```

The PersistentVolumeClaims should be bound:

```bash
$ kubectl get pvc -n malcolm
NAME                                    STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
config-claim                            Bound    pvc-90dd6987-12c3-45d5-8acb-516db28e1104   25Gi       RWX            nfs-client     <unset>                 3m12s
opensearch-backup-claim-opensearch-0    Bound    pvc-b5534ea1-e370-4e71-b0fc-434773d34f9d   25Gi       RWO            nfs-client     <unset>                 3m12s
opensearch-claim-opensearch-0           Bound    pvc-cc824212-3ce0-40a2-9e41-3e630e3e9903   25Gi       RWO            nfs-client     <unset>                 3m12s
pcap-claim                              Bound    pvc-412ec10b-ea5d-46e6-8a6a-53aeb7109441   25Gi       RWX            nfs-client     <unset>                 3m12s
postgres-claim-postgres-statefulset-0   Bound    pvc-ba220505-d4d7-43b3-beaf-d15ec0dce900   15Gi       RWO            nfs-client     <unset>                 3m12s
runtime-logs-claim                      Bound    pvc-03dd17f9-18a4-4cc6-a2a0-a8a3d5986a7b   25Gi       RWX            nfs-client     <unset>                 3m12s
suricata-claim-offline                  Bound    pvc-5897418a-5801-4dac-9d4b-074d101fc3bd   25Gi       RWX            nfs-client     <unset>                 3m12s
zeek-claim                              Bound    pvc-c30307ae-41e2-4a02-aff2-8143a17128cb   25Gi       RWX            nfs-client     <unset>                 3m12s
```

And several sub-directories will have been created under the NFS server's exported path:

```bash
$ ls -al
total 4
drwxrwxrwx 11 1000  1000   4096 Jan 15 13:35 .
drwxrwxrwx 10 1000  1000   213 Jan 18 08:02 ..
drwxrwxrwx  8 root  root   116 Jan 15 13:35 malcolm-config-claim-pvc-90dd6987-12c3-45d5-8acb-516db28e1104
drwxrwxrwx  2 root  root   6 Jan 15 13:35 malcolm-opensearch-backup-claim-opensearch-0-pvc-b5534ea1-e370-4e71-b0fc-434773d34f9d
drwxrwxrwx  4 root  root   49 Jan 15 13:36 malcolm-opensearch-claim-opensearch-0-pvc-cc824212-3ce0-40a2-9e41-3e630e3e9903
drwxrwxrwx  4 root  root   49 Jan 15 13:35 malcolm-pcap-claim-pvc-412ec10b-ea5d-46e6-8a6a-53aeb7109441
drwxrwxrwx  3 root  root   22 Jan 15 13:36 malcolm-postgres-claim-postgres-statefulset-0-pvc-ba220505-d4d7-43b3-beaf-d15ec0dce900
drwxrwxrwx  3 root  root   27 Jan 15 13:35 malcolm-runtime-logs-claim-pvc-03dd17f9-18a4-4cc6-a2a0-a8a3d5986a7b
drwxrwxrwx  2 1000  1000   54 Jan 15 13:36 malcolm-suricata-claim-offline-pvc-5897418a-5801-4dac-9d4b-074d101fc3bd
drwxrwxrwx  7 root  root   109 Jan 15 13:35 malcolm-zeek-claim-pvc-c30307ae-41e2-4a02-aff2-8143a17128cb
```

## <a name="HelmChartUpdate"></a>Updating Malcolm-Helm for a New Malcolm Release

Upgrading Malcolm-Helm to a new version of Malcolm requires manually applying the changes between the current and desired versions. To find the current version of Malcolm used by Malcolm-Helm, check the `appVersion` in the `./chart/Chart.yaml` file.

Here’s a step-by-step guide for updating Malcolm-Helm to support a new version of Malcolm. The following example demonstrates updating from version `24.09.0` to `24.11.0`.

1. Visit Malcolm's [releases page](http://github.com/idaholab/Malcolm/releases) on GitHub and read the release notes for the new version of Malcolm, especially the section on **Configuration changes** towards the bottom if it is present.

2. In a working copy of the Malcolm-Helm repository, check out the Malcolm-Helm branch containing the current version of the chart (e.g., `24.07.0`):

```bash
$ git checkout main
git checkout main
Your branch is up to date with 'idaholab/main'.

$ grep -Pi "^(app)?Version" chart/Chart.yaml
version: 25.9.0
appVersion: "25.09.0"
```

3. In a working copy of the [Malcolm repository](https://github.com/idaholab/Malcolm), check out the Malcolm branch matching the current version supported by Malcolm-Helm (e.g., `24.09.0`):

```bash
$ git checkout v25.09.0
Note: switching to 'v25.09.0'.

...

HEAD is now at b77e3eb3 Merge branch 'staging' of https://github.com/idaholab/Malcolm
```

4. View the changes between the current version (`v25.09.0`) and the new desired version (`v25.11.0`) and make note of any changes that may need to be reflected in the Helm chart.
    * This can be done either of two ways:
        - Using `git difftool` (e.g., `git difftool -d v25.09.0..v25.11.0`)
        - Using a web browser using GitHub's `compare` tool with a URL like [https://github.com/idaholab/Malcolm/compare/**v25.09.0**...**v25.11.0**?files#files_bucket](https://github.com/idaholab/Malcolm/compare/v25.09.0...v25.11.0?files#files_bucket)
    * Make particular note of changes to the [environment variable files in `./config`](https://github.com/idaholab/Malcolm/tree/main/config) as they will most likely need to be modified accordingly in the Helm chart.

5. For each relevant change identified in step 4, modify the corresponding files in Malcolm-Helm to reflect the updates. Ensure that all necessary changes are accurately mirrored.

6. Launch an instance of Malcolm-Helm to verify the upgrade, ensuring there are no breaking changes and that the system functions as expected.


## Deploying Malcolm-Helm on Cloud Service Providers

Please see the documentation pages for each cloud service provider below:

  [**Deploying Malcolm-Helm on Azure**](docs/Azure.md)


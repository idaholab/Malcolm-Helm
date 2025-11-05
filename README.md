# Malcolm Helm Chart

The purpose of this project is to facilitate installing [Malcolm](https://idaholab.github.io/Malcolm/), with all of its server and sensor components, across a Kubernetes cluster.

For more information on Malcolm and its features, see:

* [Malcolm documentation](https://idaholab.github.io/Malcolm/)
* [Malcolm learning tree](https://github.com/cisagov/Malcolm/wiki/Learning)
* [Malcolm training tutorial videos](https://www.youtube.com/@malcolmnetworktrafficanalysis/videos)

## Demonstration Using Vagrant

For the purposes of demonstration, this repository contains a Vagrantfile for quick creation of a virtualized single-node Kubernetes installation with the Malcolm Helm chart installed.

It is [required](https://idaholab.github.io/Malcolm/docs/system-requirements.html#SystemRequirements) that your host machine has at least 8 CPU cores, 16 GB of RAM and 500GB of free space. The virtual machine's resources and other configuration options can be overriden via the following environment variables:

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

### Vagrant Quickstart (without Istio)

1. [Download](https://www.virtualbox.org/wiki/Downloads) and install VirtualBox (virt-manager or VMware are also options)
2. [Download](https://developer.hashicorp.com/vagrant/downloads) and install Vagrant
3. Install required Vagrant plugins:
    * `vagrant plugin install vagrant-disksize`
    * `vagrant plugin install vagrant-reload`
4. `cd /path/to/Malcolm-Helm`
5. `vagrant up`
6. Wait for installation to complete (signaled by the "You may now ssh to your kubernetes cluster..." message)
7. Open a web browser and navigate to `http://localhost:8080` to display the Malcolm landing page.
    * The default username/password is `malcolm`/`malcolm`, although it is preferred that users set their own credentials in the `MALCOLM_USERNAME` and `MALCOLM_PASSWORD` environment variables as described above
    * It may take several minutes for all Malcolm's services to become available.
8. If desired, SSH into the VM with `ssh -p 2222 vagrant@localhost` and the password `vagrant`

### Vagrant Quickstart (with Istio)

To configure Kubernetes to use the Istio service mesh instead of using RKE2 ingress, follow the **Vagrant Quickstart** steps with the following adjustments:

* Run `VAGRANT_SETUP_CHOICE=use_istio vagrant up` (rather than `vagrant up`) to bring up the virtual machine
* With elevated privileges, edit the system `hosts` file (`/etc/hosts` for Linux, `C:\Windows\System32\drivers\etc\hosts` for Windows) and add:
    - `127.0.0.1 localhost malcolm.vp.bigbang.dev`
* Malcolm will be accessible at `https://malcolm.vp.bigbang.dev:8443`
    - If prompted with "Your connection is not private", either add the self-signed certificates to the browser's trusted store or, if using Chrome, click anywhere on the error page and type `thisisunsafe`.

### Listener NIC Setup

For the Malcolm-Helm VM to be able to inspect network traffic on its virtual NIC, you may need to set it to "promiscuous mode." Doing this will vary depending on your virtualization platform, but for VirtualBox:

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

## Production Cluster Requirements

For larger-scale production environments, the following requirements should be satisfied prior to installing the Helm chart. Other configurations may work but have not been tested.

* Kubernetes RKE2 installation (`v1.24.10+rke2r1` has been tested)
* Storage class that is capable of handling `ReadWriteMany` volumes across all Kubernetes nodes (e.g., Longhorn) 
* Storage class that is built for local / fast storage for the statefulsets
  * TODO: still need to convert OpenSearch to statefulset as well as postgreSQL for NetBox
* [Istio service mesh](https://istio.io/latest/docs/setup/getting-started)

### Label requirements

All primary server nodes should be labeled with `kubectl label nodes <node-name> cnaps.io/node-type=Tier-1`. Failure to do so will result in certain services (e.g., Logstash) not being provisioned.

All sensor nodes should be labeled with one or more of the following:

* `kubectl label nodes <node-name> cnaps.io/suricata-capture=true` 
* `kubectl label nodes <node-name> cnaps.io/zeek-capture=true`

Failure to add any of the above labels will result in traffic capture pods not being provisioned on those nodes.

The Vagrant demonstration discussed above handles and applies all these labels for you. 

## External Elasticsearch notes

Elasticsearch requires TLS termination in order for it to support Single Sign On (SSO) functionality. The values file was updated to give the user of this Helm chart the ability to copy the certificate file from a different namespace into Malcolm namespace for usage.

Furthermore, the Kibana interface (specified via `dashboards_url`) is still expected to remain unencrypted when using Istio service mesh.

## Production Installation Procedure

Check the `chart/values.yaml` file for all the features that can be enabled, disabled, and tweaked prior to running the installation commands:

```bash
git clone github.com/idaholab/Malcolm-Helm /path/to/Malcolm-Helm
cd /path/to/Malcolm-Helm
helm install malcolm chart/ -n malcolm
```

## Storage Provisioner Options

Malcolm-Helm's `chart/values.yaml` file defaults to the Rancher [local-path](https://github.com/rancher/local-path-provisioner) storage provisioner which allocates storage from the Kubernetes nodes' local storage. As stated above, any storage provider that supports the `ReadWriteMany` access mode may be employed for Malcolm-Helm. This section provides an example of how to configure the [nfs-subdir-external-provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner) for enviroments with an NFS server available. 

### Configure an NFS server

[nfs-subdir-external-provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner) relies on an external NFS server to provide Kubernetes PersistentVolumes. The first step is to install an NFS server where the Kuberentes cluster can access the NFS shared volumes. For Debian-based systems (including Ubuntu) [this page](https://documentation.ubuntu.com/server/how-to/networking/install-nfs/index.html) details steps to install an NFS server with `apt`:

```bash
sudo apt install nfs-kernel-server
sudo systemctl start nfs-kernel-server.service
```

With the NFS service installed and running, a directory must be exported for use by the Kubernetes provisioner. In this example we export a directory for the nfs-subdir-provisioner by first creating a folder structure on the server's local filesystem, then add that path to `/etc/exports` on the NFS server. To verify everything works properly we will start with fully-open directory permissions.

```bash
sudo mkdir -p /exports/malcolm/nfs-subdir-provisioner
sudo chown nobody:nogroup /exports
sudo chmod -R 777 /exports/malcolm/nfs-subdir-provisioner/
```

Add a new line to the NFS server's `/etc/exports` with the base path of our newly created `/exports` directory and an optional network subnet filter. In the following example we limit NFS access to IP addresses within the `10.0.0.0/16` subnet. This can also be replaced with an asterisk `*` symbol to disable subnet filtering.

```
/exports 10.0.0.0/255.255.0.0(rw,sync,insecure,no_root_squash,no_subtree_check,crossmnt)
```

Finally, apply the NFS configuration changes with the exportfs command

```bash
$ sudo exportfs -av
exporting 10.0.0.0/255.255.0.0:/exports
```

Optionally, we can verify the exported directory by querying the NFS server with `showmount`.

```bash
$ usr/sbin/showmount -e nfsserver.malcolm.local
Export list for nfsserver.malcolm.local:
/exports 10.0.0.0/255.255.0.0
```

Make note of your NFS server's IP address or DNS name and the exported path for use in the next steps.

### Install the nfs-client on all Kubernetes nodes

Since the Kubernetes pods will be making use of the NFS server export and the pods may run on any Kubernetes node we need the NFS client installed on all nodes. Connect to each machine and run the following commands:

```bash
sudo apt update
sudo apt install nfs-common -y
```

### Install the nfs-subdir-external-provisioner

The [nfs-subdir-exeternal-provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner) can be installed via [via Helm](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner?tab=readme-ov-file#with-helm) (as demonstrated below), with Kustomize, or manually via a set of YAML manifests.

For these steps we will need the NFS server's IP address or DNS host name as well as the NFS exported path from above. In the following example the server's DNS name is `nfsserver.malcolm.local` and the exported path on that server is `/exports/malcolm/nfs-subdir-provisioner`. Note that although the NFS server's export path is actually `/exports`, we can point the nfs-subdir-external-provisioner to a sub-directory within the exported path (e.g., `/exports/malcolm/nfs-subdir-provisioner`) to keep the files created by Malcolm contained to that directory. We start by adding the Helm repo, then install the provisioner with the server name and exported path as parameters.
 
```bash
$ helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
$ helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server=nfsserver.malcolm.local \
    --set nfs.path=/exports/malcolm/nfs-subdir-provisioner 
```

Ensure the storage class was successfully deployed to your Kubernetes cluster:

```bash
$ kubectl get sc -A
NAME                   PROVISIONER                                     RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
nfs-client             cluster.local/nfs-subdir-external-provisioner   Delete          Immediate              true                   16s
```

You will see a new `nfs-subdir-external-provisioner` running in the default namespace:

```bash
$ kubectl get pods -A
NAMESPACE       NAME                                               READYs   STATUS              RESTARTS      AGE
default         nfs-subdir-external-provisioner-7ff748465c-ssf7s   1/1     Running             0             32s
```

### Test the newly installed nfs-subdir-external-provisioner

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

This Pod definition lists `test-claim` in the `volumes:`` section at the bottom of the file which matches the PersistentVolumeClaim's `name` field above and ties the two together.

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

We test that the pod is running:
```bash
$ kubectl get pods -n default
NAME                                               READY   STATUS      RESTARTS   AGE
nfs-subdir-external-provisioner-7ff748465c-q5hbl   1/1     Running     0          27d
test-pod                                           0/1     Completed   0          7m31s
```

The PerstentVolumeClaim should make a new directory in the NFS export and the Pod is designed to exit after creating a `SUCCESS` file in that directory. The test-pod shows a status of `Completed` because the pod already started, created the file, and exited. Check the NFS directory to verify a new directory has been created and it contains a file named `SUCCESS`.

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

Delete the pod and the PersistentVolumeClaim using the same YAML files we used to create them:

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

### Configure Malcolm-Helm to use the nfs-subdir-external-provisioner

Now that we know the NFS server exports are configured correctly, and the Kubernetes nfs-subdir-external-provisioner is able to access those for PersistentVolumeClaims, we are ready to configure Malcolm-Helm for deployment. As stated above, the Malcolm-Helm [`values.yaml` file](https://github.com/idaholab/Malcolm-Helm/blob/main/chart/values.yaml) defaults to the [Rancher local-path](https://github.com/rancher/local-path-provisioner) storage provisioner. We will need to change all of those `values.yaml` entries to `nfs-client` to leverage the `nfs-subpath-external-provisioner` and the NFS server exports. The `storage:`` section of your `values.yaml` file should look like the following:

```
storage:
  # This helm chart requires a storage provisioner class it defaults to local-path provisioner
  # If your kubernetes cluster has a different storage provisioner please ensure you change this name.
  # https://github.com/rancher/local-path-provisioner
  development:
    pcap_claim:
      # The size of the claim
      size: 25Gi
      # The kubernetes storage class name
      className: nfs-client
    zeek_claim:
      size: 25Gi
      className: nfs-client
    suricata_claim:
      size: 25Gi
      className: nfs-client
    config_claim:
      size: 25Gi
      className: nfs-client
    runtime_logs_claim:
      size: 25Gi
      className: nfs-client
    opensearch_claim:
      size: 25Gi
      className: nfs-client
    opensearch_backup_claim:
      size: 25Gi
      className: nfs-client
    postgres_claim:
      size: 15Gi
      className: nfs-client
  production:
    pcap_claim:
      size: 100Gi
      className: nfs-client
    zeek_claim:
      size: 50Gi
      className: nfs-client
    suricata_claim:
      size: 50Gi
      className: nfs-client
    config_claim:
      size: 25Gi
      className: nfs-client
    runtime_logs_claim:
      size: 25Gi
      className: nfs-client
    opensearch_claim:
      size: 25Gi
      className: nfs-client
    opensearch_backup_claim:
      size: 25Gi
      className: nfs-client
    postgres_claim:
      size: 15Gi
      className: nfs-client

```

Now follow the [Installation procedures](#installation-procedures) section above to deploy the Malcolm-Helm chart into your cluser.

```
1. `cd <project dir that contains chart foler>`
2. `helm install malcolm chart/ -n malcolm --create-namespace`
```

returns:

```
```
NAME: malcolm
LAST DEPLOYED: Tue Jul 15 13:35:51 2025
NAMESPACE: malcolm
STATUS: deployed
REVISION: 1
TEST SUITE: None
```
```

The Malcolm-Helm pods should all be Running after a few minutes:

```
Malcolm-Helm$ kubectl get pods -n malcolm
NAME                                           READY   STATUS    RESTARTS   AGE
api-deployment-8685768bbd-8kr8x                1/1     Running   0          103s
arkime-deployment-7dbf5f99c5-nrgxm             1/1     Running   0          103s
dashboards-deployment-5897d7cfcf-nh9r6         1/1     Running   0          103s
dashboards-helper-deployment-758645fdc-vggnq   1/1     Running   0          101s
file-monitor-deployment-64c595db-2xwlp         1/1     Running   0          103s
filebeat-offline-deployment-596bb57f5b-4hl89   1/1     Running   0          103s
freq-deployment-bb49df764-frhqt                1/1     Running   0          103s
htadmin-deployment-7658bf6ff5-bwqqg            1/1     Running   0          101s
logstash-deployment-569899b584-758nw           1/1     Running   0          102s
netbox-deployment-654cb5598c-c58n8             1/1     Running   0          103s
nginx-proxy-deployment-5db4b75948-8ltpx        1/1     Running   0          103s
opensearch-0                                   1/1     Running   0          103s
pcap-monitor-deployment-84986f9ccc-wd45z       1/1     Running   0          103s
postgres-statefulset-0                         1/1     Running   0          103s
redis-cache-deployment-644f9947f4-6dwqk        1/1     Running   0          103s
redis-deployment-677476f956-782n4              1/1     Running   0          102s
suricata-offline-deployment-678fcdc985-mmj67   1/1     Running   0          103s
upload-deployment-6b458f89c7-k8hd8             1/1     Running   0          103s
zeek-offline-deployment-57c548c646-d86lw       1/1     Running   0          102s
```

The PersistenVolumeClaims should be bound:

```
Malcolm-Helm$ kubectl get pvc -n malcolm
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

And you should see several sub-directories were created in the NFS server export directory:

```
nfs-subdir-provisioner$ ls -al
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


## Upgrade procedures

Upgrading Malcolm-Helm to a new version of Malcolm requires manually applying the changes between the current and desired versions. To find the current version of Malcolm used by Malcolm-Helm, check the `appVersion` in the `Malcolm-Helm/chart/Chart.yaml` file.

Here’s a step-by-step guide for upgrading Malcolm-Helm to a new version of Malcolm. The following example demonstrates an upgrade from version `24.07.0` to `24.10.0`, which is the latest release on Malcolm/main at the time of writing.

Step 1:
Checkout the Malcolm-Helm branch containing the current version of Malcolm (24.07.0)
Run the following command to checkout the relevant branch:
`git checkout Malcolm-Helm/main`

Step 2:
Checkout the Malcolm branch matching the current version in Malcolm-Helm (24.07.0)
Use this command to align your Malcolm repo with the version used in Malcolm-Helm:
`git checkout Malcolm/v24.07.0`

Step 3:
View the changes between the current version (v24.07.0) and the new desired version (main)
Compare the changes between these two versions to understand what updates need to be applied:
`git difftool -d v24.07.0..main`

Step 4:
Map changes to Malcolm-Helm files
For each change identified in Step 3, modify the corresponding files in Malcolm-Helm to reflect the updates. Ensure that all changes are accurately mirrored.

Step 5:
Test the updated Malcolm-Helm configuration
After mapping all changes, launch Dataplane's Malcolm instance to verify the upgrade. Ensure there are no breaking changes and that everything functions as expected.

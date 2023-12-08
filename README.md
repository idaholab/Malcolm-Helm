# Malcolm Helm Chart

The purpose of this project is to make installing Malcolm with all of its server and sensor components easily across a 
large Kubernetes cluster. Case in point, lets say you have 8 servers and 50 sensors. Some sensors will be high bandwidth 
while others may be low bandwith. This helm chart for example can either deploy a opensearch setup or point to a 
preconfigured external elasticsearch.  Furthermore, it will deploy live sensors for suricata and zeek as well as offline 
deployment for uploading pcaps offline.

## Features

Malcolm comes with a wide variety of including but not limited to the following:

- Opensearch or External Elastic
- Netbox
- PCAP capture
- Arkime PCAP Capture (Not implemented yet)
- Suricata Live
- Zeek Live
- Offline PCAP Processing
- Zeek file extraction 

For a more comprehensive list of components navigate to https://malcolm.fyi/docs/components.html. 

## Vagrant Quickstart

It is required that your host machine has 500GB of free space, 16 GB of free RAM and 8 extra CPU cores to run this quickstart.

1. Install virtual box version 7.0.10 r158379 or greater from https://www.virtualbox.org/wiki/Downloads
2. Install vagrant version 2.4.0 or greater from https://developer.hashicorp.com/vagrant/downloads
3. Install vagrant disk size plugin verion 0.1.3 with `vagrant plugin install vagrant-disksize`
4. Install vagrant reload version 0.0.1 with `vagrant plugin install vagrant-reload`
5. Run `cd <root of the project where the Vagrantfile is located>`
6. Run `vagrant up`
7. Wait until everything installs at the end of the install you should see the ssh command echo out.
8. run `ssh -p 2222 vagrant@localhost` and login using vagrant as the password.
9. Open chrome and navigate to http://localhost:8080/readme (NOTE: If they dont come up make sure the pods are running and give it at least 5 minutes before trying to hit all the services. ) or any of the following URLs: 

- http://localhost:8080/dashboards/
- http://localhost:8080/upload/
- http://localhost:8080/netbox/
- http://localhost:8080/dl-extracted-files/
- http://localhost:8080/auth/

10. If prompted for credentials username is always vagrant and password is always vagrant.

### Vagrant Quickstart with istio

Running vagrant with istio service mesh example instead of using RKE2 ingress.

1. Follow steps 1 through 5 in vagrant quickstart
2. run `VAGRANT_SETUP_CHOICE=use_istio vagrant up`
3. If using Windows edit C:\Windows\System32\drivers\etc\hosts with notepad as administrator
4. If using linx run `sudo vim /etc/hosts`
5. Add the entry `127.0.0.1 localhost malcolm.vp.bigbang.dev`
6. Open chrome and navigate to https://malcolm.vp.bigbang.dev:8443/readme
7. If the browser does not allow you to access the page. Either add the ca.crt generated to the webrowser or just click on the webbrowser and type `thisisunsafe`

## Listener NIC setup

If you want all the host traffic to be seen by the Malcolm-Helm VM running on your host machine execute the following instructions:

1. Open virtualbox 
2. Right click Malcolm-Helm VM and select settings
3. Select Network on the left colum
4. Select `Adapter 2` tab
5. Change Attached to `Bridged Adapter`
6. Select the Advanced drop down
7. Ensure Promisc mode is set to `Allow all` 
8. run `ssh -p 2222 vagrant@localhost` and login using vagrant as the password.
9. run `tcpdump -i enp0s8` to ensure traffic is getting piped through the iface.

## Production Cluster Requirements

The following requirements pertain to only a Kubernetes cluster you are standing up for production purposes.
The following requirements are assumed to be met prior to running the Installation procedures.  
Other Kuberenetes clusters may work but they have not been tested

- Kubernetes RKE2 installation v1.24.10+rke2r1
- Storage class that is capable of handling ReadWriteManyVolumes across all kubernetes nodes (IE: Longhorn) 
- TODO Storage class that is built for local / fast storage for the statefulsets. (We still need to convert Opensearch to statefulset as well as postgres for netbox.)
- Istio service mesh https://istio.io/latest/docs/setup/getting-started/
- TODO Support TLS with nginx ingress

### Label requirements

NOTE: The vagrant quick start handles and applies all these labels for you.
All primary server nodes should be labeled with `kubectl label nodes $node_name cnaps.io/node-type=Tier-1`.  Failure to do so will result in certain services like logstash to not be provisioned.

All sensor kubernetes nodes should be labeled with one or all of the following:
1. `kubectl label nodes $node_name cnaps.io/suricata-capture=true` 
2. `kubectl label nodes $node_name cnaps.io/zeek-capture=true`

Failure to add any of the above labels will result in suricata and zeek live pods to not get scheduled on those nodes.

## External Elasticsearch notes

Elasticsearch requires TLS termination in order for it to support Single Sign On (SSO) functionality.  The values file was updated to give 
the user of this helm chart the ability to copy the certificate file from a different namespace into Malcolm namespace for usage.

Furthermore, dashboards_url (IE kibana) is still expected to remain unencrypted when using Istio service mesh. 

## Installation procedures

Check the chart/values.yaml file for all the features that can be enabled disabled and tweaked prior to running the below installation commands.

1. `git clone <repo url>`
2. `cd <project dir that contains chart foler>`
3. `helm install malcolm chart/ -n malcolm`

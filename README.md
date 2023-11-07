# Installation procedures

1. `git clone <repo url>`
2. `cd <project dir that contains chart foler>`
3. `helm install malcolm chart/ -n malcolm`

## Accessing services with istio service mesh

1. Copy the EXERNAL-IP of the gateway using the `kubectl get svc -n istio-system` command.
2. Grab the hostname under the HOSTS column using `kubectl get virtualservice -n malcolm`
3. Update /etc/hosts file with `sudo vim /etc/hosts`(EX: append "10.1.25.70 malcolm.vp.bigbang.dev" )

Malcolm services can be accessed via the following URLs:
-----------------------------------------------------------
  - Arkime: https://yourhostname/
  - OpenSearch Dashboards: https://yourhostname/dashboards/
  - PCAP upload (web): https://yourhostname/upload/
  - PCAP upload (sftp): sftp://username@yourhostname:8022/files/
  - NetBox: https://yourhostname/netbox/
  - Account management: https://yourhostname/auth/
  - Documentation: https://yourhostname/readme/

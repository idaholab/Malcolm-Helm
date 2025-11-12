Please review the [**Malcolm-Helm README**](https://github.com/idaholab/Malcolm-Helm) carefully, particularly the sections on [**Production Cluster Requirements**](https://github.com/idaholab/Malcolm-Helm?tab=readme-ov-file#ProductionReqs) and [**Label Requirements**](https://github.com/idaholab/Malcolm-Helm?tab=readme-ov-file#Labels), before proceeding.

# Using the Malcolm-Helm repository

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

* Optionally, create [`values.yaml`](https://github.com/idaholab/Malcolm-Helm/blob/main/chart/values.yaml) and modify as necessary:

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

# Packaging and Publishing a Malcolm-Helm release

```bash
$ git clone --branch helm-repo https://github.com/idaholab/Malcolm-Helm Malcolm-Helm-repo
Cloning into 'Malcolm-Helm-repo'...
…
Resolving deltas: 100% (1487/1487), done.

$ git clone --branch main https://github.com/idaholab/Malcolm-Helm Malcolm-Helm-main
Cloning into 'Malcolm-Helm-main'...
…
Resolving deltas: 100% (1487/1487), done.

$ cd Malcolm-Helm-repo/malcolm-25.x.x/

$ helm package ../../Malcolm-Helm-main/chart/
Successfully packaged chart and saved it to: Malcolm-Helm-repo/malcolm-25.x.x/malcolm-25.11.0.tgz

$ cd ..

$ helm repo index . --merge ./index.yaml

$ git add index.yaml malcolm-25.x.x/malcolm-25.11.0.tgz

$ git status .
On branch helm-repo
Your branch is up to date with 'origin/helm-repo'.

Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
    modified:   index.yaml
    modified:   malcolm-25.x.x/malcolm-25.11.0.tgz

$ git commit -s -m "Packag Malcolm-Helm v25.11.0"
[helm-repo 600dbeef] Packaged v25.11.0 for release
 2 files changed, 4 insertions(+), 4 deletions(-)

$ git push
…
To https://github.com/idaholab/Malcolm-Malcolm
   001dbeef..600dbeef  helm-repo -> helm-repo
```

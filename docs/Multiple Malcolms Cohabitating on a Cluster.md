# Tips for Multiple Malcolm Instances on a Cluster

*Seth Grover, 2026-02-11*

This document exists to collect some of the things I've learned about deploying the Malcolm Helm chart onto a cluster in a way that keeps it separate from other instances that may be on there.

# Labels

The Malcolm-Helm README's **Label requirements** section talks about applying node labels that determine on which nodes some services are deployed. If there's a chance other Malcolm instances may be using the same labels, we want to keep ours separate. I've chosen a suffix (`-sg`, my initials) to keep my "private" labels separated from others.

## Scripts to Label and Unlabel things

These scripts require `kubectl` and `jq`.

### clear-private-labels.sh

This script clears my private labels from all nodes in the cluster:

```bash
#!/usr/bin/env bash

set -euo pipefail

MY_TRUE_VALUE="true-sg"
MY_TIER1_VALUE="Tier-1-sg"

CAP_LABEL_KEYS=(
  "cnaps.io/arkime-capture"
  "cnaps.io/suricata-capture"
  "cnaps.io/zeek-capture"
  "cnaps.io/zeek-remote-capture"
  "cnaps.io/pcap-capture"
)

NODE_TYPE_KEY="cnaps.io/node-type"

for NODE in $(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); do
  echo "==> $NODE"

  # Grab node JSON once
  NODE_JSON="$(kubectl get node "$NODE" -o json)"

  # Remove capture labels only if they match your value
  for KEY in "${CAP_LABEL_KEYS[@]}"; do
    CUR="$(jq -r --arg k "$KEY" '.metadata.labels[$k] // empty' <<<"$NODE_JSON")"
    if [[ "$CUR" == "$MY_TRUE_VALUE" ]]; then
      echo "  removing $KEY=$CUR"
      kubectl label node "$NODE" "${KEY}-"
    fi
  done

  # Remove node-type only if it matches your value
  CUR_TYPE="$(jq -r --arg k "$NODE_TYPE_KEY" '.metadata.labels[$k] // empty' <<<"$NODE_JSON")"
  if [[ "$CUR_TYPE" == "$MY_TIER1_VALUE" ]]; then
    echo "  removing $NODE_TYPE_KEY=$CUR_TYPE"
    kubectl label node "$NODE" "${NODE_TYPE_KEY}-"
  fi
done
```

### set-private-labels.sh

This script clears sets my private labels on their appropriate nodes:

```bash
#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Same key, unique value labeling strategy
#
# This script applies labels like:
#   cnaps.io/node-type=Tier-1-sg
#   cnaps.io/arkime-capture=true-sg
#   cnaps.io/zeek-remote-capture=true-sg
#
# Adjust arrays below to choose which nodes get which labels.
###############################################################################

MY_TRUE_VALUE="true-sg"
MY_TIER1_VALUE="Tier-1-sg"

# ---- Node groups (edit these) -----------------------------------------------

TIER1_NODES=(
  node-abc
  node-def
  node-ghi
)

ARKIME_NODES=(
  node-jkl
  node-mno
  node-pqr
)

SURICATA_NODES=(
  node-jkl
  node-mno
  node-pqr
)

ZEEK_NODES=(
  node-jkl
  node-mno
)

ZEEK_REMOTE_NODES=(
  node-pqr
)

PCAP_NODES=(
)

###############################################################################
# Helper
###############################################################################
label_nodes() {
  local key="$1"
  local value="$2"
  shift 2
  local nodes=( "$@" )

  if [[ "${#nodes[@]}" -eq 0 ]]; then
    echo "Skipping ${key} (no nodes configured)"
    return 0
  fi

  for node in "${nodes[@]}"; do
    echo "Labeling ${node}: ${key}=${value}"
    kubectl label node "$node" "${key}=${value}" --overwrite
  done
}

###############################################################################
# Apply labels
###############################################################################

# Tiering label used by node_count_label (logstash scaling helper)
label_nodes "cnaps.io/node-type" "${MY_TIER1_VALUE}" "${TIER1_NODES[@]}"

# Capture role labels
label_nodes "cnaps.io/arkime-capture"      "${MY_TRUE_VALUE}" "${ARKIME_NODES[@]}"
label_nodes "cnaps.io/suricata-capture"    "${MY_TRUE_VALUE}" "${SURICATA_NODES[@]}"
label_nodes "cnaps.io/zeek-capture"        "${MY_TRUE_VALUE}" "${ZEEK_NODES[@]}"
label_nodes "cnaps.io/zeek-remote-capture" "${MY_TRUE_VALUE}" "${ZEEK_REMOTE_NODES[@]}"
label_nodes "cnaps.io/pcap-capture"        "${MY_TRUE_VALUE}" "${PCAP_NODES[@]}"

echo "Done."
```

## Changing Node Selection Criteria to use Private Labels

### sg-node-selectors.yaml

When installing the Helm chart, I apply this file to override the default values associated with label-based node selection:

```yaml
node_count_label:
  key: cnaps.io/node-type
  value: Tier-1-sg

arkime_live:
  nodeSelector:
    cnaps.io/arkime-capture: "true-sg"

suricata_live:
  nodeSelector:
    cnaps.io/suricata-capture: "true-sg"

zeek_live:
  nodeSelector:
    cnaps.io/zeek-capture: "true-sg"
  remoteNodeSelector:
    cnaps.io/zeek-remote-capture: "true-sg"

pcap_live:
  nodeSelector:
    cnaps.io/pcap-capture: "true-sg"

pcap_processor_env:
  nodeSelector:
    cnaps.io/arkime-capture: "true-sg"

filebeat:
  daemonsetNodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: cnaps.io/suricata-capture
              operator: In
              values: ["true-sg"]
            - key: cnaps.io/zeek-remote-capture
              operator: DoesNotExist
        - matchExpressions:
            - key: cnaps.io/suricata-capture
              operator: In
              values: ["true-sg"]
            - key: cnaps.io/zeek-remote-capture
              operator: NotIn
              values: ["true-sg"]
        - matchExpressions:
            - key: cnaps.io/zeek-capture
              operator: In
              values: ["true-sg"]
            - key: cnaps.io/zeek-remote-capture
              operator: DoesNotExist
        - matchExpressions:
            - key: cnaps.io/zeek-capture
              operator: In
              values: ["true-sg"]
            - key: cnaps.io/zeek-remote-capture
              operator: NotIn
              values: ["true-sg"]
```

## Using A Custom NFS Provisioner

This is described in the **Install the nfs-subdir-external-provisioner** section of the README. I'm using the `-sg` suffix here too so as not to cross the streams with other instances of nfs-subdir-external-provisioner that might be in use.

```bash
helm install nfs-subdir-malsg \
    nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    -n default \
    --set nfs.server=192.168.9.47 \
    --set nfs.path=/exports/storage-ssd/malcolm/nfs-subdir-provisioner \
    --set storageClass.name=nfs-client-malsg \
    --set storageClass.provisionerName=cluster.local/nfs-subdir-malsg \
    --set fullnameOverride=nfs-subdir-malsg
```

## Deploying the Helm Chart

### install.sh

This is just an example of the `helm install` command (with `helm template` and `kubeconform` first to check it for correctness). There are a few examples of some settings overrides here; use your own `--set` arguments as needed. Set the `KUBESPACE` environment variable to the desired namespace before running. Note the `-f ./sg-node-selectors.yaml` using the node selection criteria YAML file in the previous section, and the use of `storage_class_name=nfs-client-malsg` which we just created.

```bash
#!/usr/bin/env bash

[[ -f .envrc ]] && source .envrc

[[ -z "$KUBESPACE" ]] && exit 1
[[ -f ./sg-node-selectors.yaml ]] || exit 1

# create secret for auth
kubectl create namespace "$KUBESPACE"

kubectl create secret generic -n "$KUBESPACE" malcolm-auth \
  --from-literal=username="SuperSecretUsername" \
  --from-literal=openssl_password="$(openssl passwd -1 'SuperSecretPassword' | tr -d '\n' | base64 | tr -d '\n')" \
  --from-literal=htpass_cred="$(htpasswd -bnB 'SuperSecretUsername' 'SuperSecretPassword' | head -n1)"

for OP in template install; do
    > ./"$OP".txt
    helm "$OP" $KUBESPACE ./chart -n $KUBESPACE -f ./sg-node-selectors.yaml \
    --set-string auth.existingSecret=malcolm-auth \
    --set is_production=true \
    --set-string capture_mode=live \
    --set pcap_capture_env.pcap_iface=primary0 \
    --set-string storage_class_name=nfs-client-malsg \
    --set-string arkime_live.hostpath=/var/lib/malcolm-sg/arkime-pcap \
    --set-string filescan_env.hostpath=/var/lib/malcolm-sg/filescan-logs \
    --set-string redis_env.hostpath=/var/lib/malcolm-sg/redis-aof \
    --set-string suricata_live.hostpath=/var/lib/malcolm-sg/suricata-logs \
    --set-string zeek_live.hostpath.extracted=/var/lib/malcolm-sg/extracted-files \
    --set-string zeek_live.hostpath.logs=/var/lib/malcolm-sg/zeek-logs \
    --set-string cluster.node_cidr=192.168.9.0/24 \
    --set istio.enabled=false \
    --set ingress.enabled=true \
    --set ingress.specRules.rules[0].http.paths[0].path=/ \
    --set ingress.specRules.rules[0].http.paths[0].pathType=Prefix \
    --set ingress.specRules.rules[0].http.paths[0].backend.service.name=nginx-proxy \
    --set ingress.specRules.rules[0].http.paths[0].backend.service.port.number=443 \
    --set-string ingress.specRules.rules[0].host=malcolm.example.org \
    --set-string image.pullPolicy=Always >./"$OP".txt || break
    if [[ "$OP" == "template" ]]; then
        kubeconform -strict -ignore-missing-schemas ./"$OP".txt || break
    fi
done
```

## Uninstalling

### uninstall.sh

Here I'm uninstalling the chart, deleting PVCs, and taking a sledgehammer to my persistent storage artifacts. In other words, this is how I nuke *everything* (be careful).

```bash
#!/usr/bin/env bash

[[ -f .envrc ]] && source .envrc

[[ -z "$KUBESPACE" ]] && exit 1

helm uninstall $KUBESPACE -n $KUBESPACE && sleep 10

for PVC in $(kubectl get pvc -n "$KUBESPACE" -o wide | tail -n +2 | awk '{print $1}'); do
    kubectl delete pvc -n "$KUBESPACE" "$PVC"
done

sleep 10

ssh my-nfs-server "rm -rvf /exports/storage-ssd/malcolm-sg/nfs-subdir-provisioner/*"

for NODE in node-jkl node-mno node-pqr; do
    ssh "$NODE" "rm -rvf /var/lib/malcolm-sg/*"
done
```

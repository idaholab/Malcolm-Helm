# Deploying Multiple OpenSearch Replicas

Malcom-Helm allows for [single OpenSearch node deployments](../chart/values.yaml#L151) or (with singleNode mode disabled) you can specify [Multiple OpenSearch replicas](../chart/values.yaml#L152). With the addition of the [OpenSearch Security Plugin](https://docs.opensearch.org/latest/security/) as of [Malcolm v25.06.0](https://github.com/cisagov/Malcolm/releases/tag/v25.06.0) all OpenSearch replica communications must now be encrypted with a common shared TLS certificate. With multiple OpenSearch replicas this certificate must be externally created and provided to the Malcolm-Helm platform via a [Kubernetes Secret](https://kubernetes.io/docs/concepts/configuration/secret/) prior to install. The following steps explain how to generate a TLS certificate and a Secret to hold the certificate files.

## Generating a Certificate Authority and related key ##

Use the [OpenSSL tool](https://www.openssl.org/) to generate an RSA key file named ca.key:

```bash
openssl genrsa -out ca.key 2048
```

Use that key to generate a new certificate:

```bash
openssl req -x509 -new -nodes \
  -key ca.key -sha256 -days 3650 \
  -subj "/CN=opensearch/OU=ca/O=Malcolm/ST=ID/C=US" \
  -out ca.crt
```
This should leave you with two files that we will store in a Kubernetes Secret:

```bash
$ ls -al
-rw-r--r--  1 user user 1269 Dec 14 09:27 ca.crt
-rw-------  1 user user 1704 Dec 14 09:26 ca.key
```

## Create a Kubernetes Secret from the certificate files ##

You will need to know the Kubernetes namespace (if any) for your Malcom-Helm deployment so that the Secret object will be available to Malcolm-Helm at run-time. Create the Kubernetes namespace if it doesn't already exist. For this example we will use the "existingca" namespace: 
```bash
kubectl create ns existingca
```

You should see a message that the new namespace was created successfully


> $ kubectl create ns existingca    
> namespace/existingca created    

Next create the Secret object in the appropriate namespace.    

In the command below the new Secret object is named "opensearch-ca-secret". Make note of the this name as it will be used in values.yaml modifications or command line options later. The certificate and key files created in the last step are specified for storage in the Kubernetes Secret


```bash
kubectl create secret generic opensearch-ca-secret \
  --from-file=ca.crt=./ca.crt \
  --from-file=ca.key=./ca.key \
  -n existingca
```

You should see a message that the Secret was created successfully


> $ kubectl create secret generic opensearch-ca-secret \
>     --from-file=ca.crt=./ca.crt \
>     --from-file=ca.key=./ca.key \
>     -n existingca         
> secret/opensearch-ca-secret created

Verify the Secret object contains the ca.crt and ca.key files:

```bash
kubectl describe secret opensearch-ca-secret -n existingca
```

You should see the name and namespace match what was provided above as well as a Data section listing the two Certificate Authority files.

> $ kubectl describe secret opensearch-ca-secret -n existingca
>
>       Name:         opensearch-ca-secret    
> 		Namespace:    existingca    
> 		Labels:       <none>    
> 		Annotations:  <none>    
> 		
> 		Type:  Opaque
> 		
> 		Data
> 		====
> 		ca.crt:  1269 bytes
> 		ca.key:  1704 bytes    

With the certificate information stored in the Kubernetes Secret for the appropriate namespace we are ready to customize Malcolm-Helm.

## Provide the Secret object name to Malcolm-Helm ##    

When installing Malcolm-Helm from source code you can edit the Helm Chart [values.yaml](../chart/values.yaml#L176) "existingCASecretName" value directly:    

```
opensearch:    
  singleNode: false    
  replicas: 3    
  ...    
  existingCASecretName: "opensearch-ca-secret"
```    

When [installing from the Malcolm-Helm repository](../README.md#installation-from-helm-repository) you can either provide the new Secret object name via helm install command line options. e.g.:

```bash
helm install malcolm \
  --set "opensearch.existingCASecretName=opensearch-ca-secret" \
  --set "opensearch.singleNode=false" \
  --namespace "existingca" \    
  ...
```    

or create a values.yaml file with the secret name specified:

```
opensearch:    
  singleNode: false    
  replicas: 3    
  ...    
  existingCASecretName: "opensearch-ca-secret"
```    

and pass the new values.yaml file to Helm via command line:

```bash
$ helm install malcolm malcolm/malcolm \
    --values ./values.yaml \
    --namespace "existingca" \
```    

## How this works in Malcolm-Helm ##


When the opensearch [existingCASecretName value](../chart/values.yaml#L176) is specified Malcolm-Helm [mounts the Secret's files](../chart/templates/03-opensearch.yml#L152) into every OpenSearch pod at: /usr/share/opensearch/config/certs/secretmap. Malcolm [has a mechanism](https://github.com/cisagov/Malcolm/blob/e60cbd07d8f150c6126df30ae4a90c9034dca643/shared/bin/docker-uid-gid-setup.sh#L24) that copies the Secret's contents up one directory to: /usr/share/opensearch/config/certs. With the custom Certificate Authority files in the proper place, each OpenSearch pod uses the provided certificate to [generate server and client certificates](https://github.com/cisagov/Malcolm/blob/e60cbd07d8f150c6126df30ae4a90c9034dca643/shared/bin/self_signed_key_gen.sh#L131) for that pod. Since all of the OpenSearch pods leveraged the same Certificate Authority files (provided by you) trusted encryption channels can be established between the Opensearch pods satisfying the encryption requirements of the [OpenSearch Security Plugin](https://docs.opensearch.org/latest/security/).
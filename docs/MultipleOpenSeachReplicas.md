# Deploying Multiple OpenSearch Replicas

Malcom-Helm allows for [single OpenSearch node deployments](../chart/values.yaml#L151) or (with singleNode mode disabled) you can specify [Multiple OpenSearch replicas](../chart/values.yaml#L152). With the addition of the [OpenSearch Security Plugin](https://docs.opensearch.org/latest/security/) as of [Malcolm v25.06.0](https://github.com/cisagov/Malcolm/releases/tag/v25.06.0) all OpenSearch replica communications must now be encrypted with a common shared TLS certificate. This certificate must be manually created and provided to the Malcolm-Helm platform via a [Kubernetes Secret](https://kubernetes.io/docs/concepts/configuration/secret/) prior to install. The following steps explain how to generate a TLS certificate and a Secret to hold the certificate files.

## Generating a Certificate Authority and related key ##

Using the OpenSSL tool generate an RSA key:

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
This should leave you with two files that will be stored in a Kubernetes Secret:

```bash
$ ls -al
-rw-r--r--  1 user user 1269 Dec 14 09:27 ca.crt
-rw-------  1 user user 1704 Dec 14 09:26 ca.key
```

## Create a Kubernetes Secret from the certificate files ##

You will need to know the Kubernetes namespace (if any) for your Malcom-Helm deployment so that the Secret object will be available at run-time. Create the Kubernetes namespace if it doesn't already exist: 
```bash
kubectl create ns existingca
```

You should see a message that the new namespace was created successfully


> $ kubectl create ns existingca    
> namespace/existingca created    


In the command below the new Secret object is named "opensearch-ca-secret". Make note of the this name as it will be used in values.yaml modifications later.

Create the Secret object in the appropriate namespace.:

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

You should see the name and namespace match what was provided above as well as a Data section listing the two certificate files.

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

With the certificate information stored in the Kubernetes secret in the appropriate namespace we are ready to customize Malcolm-Helm.

## Provide the Secret object name to Malcolm-Helm ##    

You can either edit the Helm Chart [values.yaml](../chart/values.yaml#L176) "existingCASecretName" value directly:    
> \# Then place the secret name below    
> \#     (e.g. existingCASecretName: "opensearch-ca-secret")    
> existingCASecretName: "opensearch-ca-secret"

or provide the new Secret object name via helm install command line options at install time. e.g.:

```bash
helm install malcolm
  --set "opensearch.existingCASecretName=opensearch-ca-secret" \
  -n "existingca" \    
  --set "opensearch.singleNode=false" \
```

04142026
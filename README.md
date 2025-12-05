Please review the [**Malcolm-Helm README**](https://github.com/idaholab/Malcolm-Helm) carefully, particularly the sections on [**Production Cluster Requirements**](https://github.com/idaholab/Malcolm-Helm?tab=readme-ov-file#ProductionReqs) and [**Label Requirements**](https://github.com/idaholab/Malcolm-Helm?tab=readme-ov-file#Labels), before proceeding.

# Using the Malcolm-Helm repository

See [**Installation From Helm Repository**](https://github.com/idaholab/Malcolm-Helm?tab=readme-ov-file#HelmRepoQuickstart) in the [**Malcolm-Helm README**](https://github.com/idaholab/Malcolm-Helm).

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

$ git commit -s -m "Package Malcolm-Helm v25.11.0"
[helm-repo 600dbeef] Packaged v25.11.0 for release
 2 files changed, 4 insertions(+), 4 deletions(-)

$ git push
…
To https://github.com/idaholab/Malcolm-Malcolm
   001dbeef..600dbeef  helm-repo -> helm-repo
```

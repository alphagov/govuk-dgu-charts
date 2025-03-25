# data.gov.uk Helm Charts

## Getting started

See [Helm's documentation](https://helm.sh/docs) to get started with Helm.

See the [GOV.UK Kubernetes cluster docs](https://govuk-kubernetes-cluster-user-docs.publishing.service.gov.uk/)
for an introduction to the cluster or ask [#govuk-platform-engineering](https://gds.slack.com/channels/govuk-platform-engineering) in Slack.

Local development uses [k3d](https://k3d.io/) which runs a Kubernetes cluster locally using Docker.

### Prerequisites

1. Install Helm

```
brew install helm
```

2. Install Docker

Install from [here](https://docs.docker.com/registry/)

3. Install k3d
```
brew install k3d
```

4. Install kubectl

```sh
brew install kubectl
```

5. Clone the repository

```sh
git clone git@github.com:alphagov/govuk-dgu-charts.git
```

### Setting up a local CKAN cluster

Advantage of using `k3d` is that we don't need to worry about creating an ingress controller. This aligns with how we 
run the cluster in EKS as that manages creation of the ingress controller for us.

1. Create the `k3d` cluster
```shell
k3d cluster create local-ckan --api-port 6550 -p "8081:80@loadbalancer" --registry-create local-registry
```

2. Switch kubectl to point to your local cluster:
```sh
kubectl config use-context k3d-local-ckan
```

3. Locate the port the registry is running on:

```sh
docker ps -f name=local-registry
```

The remaining steps will assume our local registry is running on `localhost:53492`

4. Build a docker image

If we want to push an image to our local registry we have to tag our image. 
See [here](https://distribution.github.io/distribution/about/deploying/#run-a-local-registry) 
for background on local Docker registries.

So if our local registry is running at `localhost:53492` and we want to build 
[ckan 2.10.4](https://github.com/alphagov/ckanext-datagovuk/blob/457e856fe0ff0d60edc99a4a2a88e778f37ac05f/docker/ckan/2.10.4.Dockerfile) 
we have to tag our image as follows:

```sh
docker build -t localhost:53492/ckan:2.10.4 -f docker/ckan/2.10.4.Dockerfile .
```
**Note:** for Find build the `dev.Dockerfile version`

```sh
docker build -t localhost:53492/datagovuk_find:dev -f docker/dev.Dockerfile .
```

5. Push the image to our local registry

```sh
docker push localhost:53492/ckan:2.10.4
```

6. Use the image in our Helm chart

Currently [govuk-dgu-charts/charts/ckan/values.yaml](https://github.com/alphagov/govuk-dgu-charts/blob/b6f56b6abd374584ad219f60e09ea7df20934127/charts/ckan/values.yaml) 
points to the `test` environment:

```
environment: test

ckan:
  replicaCount: 1
  ...
```

Update [govuk-dgu-charts/ckan/images/test/ckan.yaml](https://github.com/alphagov/govuk-dgu-charts/blob/b6f56b6abd374584ad219f60e09ea7df20934127/charts/ckan/images/test/ckan.yaml) with our new image so it looks like this:

```
repository: local-registry:53492/ckan
tag: 2.10.4
branch: main
```

Note that `local-registry` matches the name of the registry we passed in step 1. 
If we want to use a different image from a different environment then set `environment` appropriately. 

7. Apply the local dev Helm Chart

```sh
kubectl apply -f local-dev.yaml
```

This sets up some initial configuration in the cluster.

8. Switch to the `datagovuk` namespace

```sh
kubectl config set-context --current --namespace=datagovuk
```

9. Install the application Helm charts

```sh
helm install ckan-dev ./charts/ckan/ -n datagovuk
helm install datagovuk-dev ./charts/datagovuk/ -n datagovuk
helm install dgu-shared-dev ./charts/dgu-shared/ -n datagovuk
```

Now your local CKAN deployment will use the `localhost:54392/ckan.2.10.4` image.

10. Update the `/etc/hosts` file as follows

```sh
127.0.0.1	localhost find.data.gov.uk ckan.dev.govuk.digital
```

`datagovuk-find` can be accessed at `find.data.gov.uk:8081`
`ckan` can be accessed at `ckan.dev.govuk.digital:8081`

#### Test Helm chart in EKS

1. update the `targetRevision` in `ckan-application.yaml` or `datagovuk-application.yaml` to be the branch you want to test against.
1. update the target revision in Argo on `dgu-app-of-apps` to be the branch you want to test, normally on the Integration cluster.
1. after testing is complete remember to set the target revision back to `main` in `dgu-app-of-apps`.
1. if you are creating a PR drop the commit which updates the `targetRevision` in step 1.

### Github API token permissions

When creating fine-grained API tokens, ensure that read/write permissions for PRs and Content are allowed (this will allow for PR and commit creation) and that CI user is used to create the PRs.

## Ephemeral cluster

An ephemeral cluster is now available to test changes to the CKAN and datagovuk charts and infrastructure without impacting the other stable EKS environments.

To access the ephemeral cluster from your terminal you will need to log in to the govuk-test account

```sh
eval $(gds-cli aws govuk-test-admin -e --art 8h)
```

and follow these [steps](https://docs.publishing.service.gov.uk/kubernetes/get-started/access-eks-cluster/#access-a-cluster-for-the-first-time) to switch to the test environment.

If there is an existing ephemeral datagovuk cluster running you can delete the datagovuk cluster by deleting `dgu-app-of-apps` in the ephemeral argo website and recreate the cluster by running this command on the terminal under the `charts` directory (the environment variable passed in should match your ephemeral cluster name):

```sh 
helm upgrade -n cluster-services datagovuk-argo-bootstrap argo-bootstrap --set environment=eph-aaa113
```

To test your changes on the ephemeral cluster without merging them into the `main` branch:

- update the `targetRevision` in the `ckan-application.yaml` and/or `datagovuk-application.yaml` and push this change up to your branch onto Github
- if you have deleted the `dgu-app-of-apps` module then run the `helm upgrade` command as above
- update the `targetRevision` in `dgu-app-of-apps` on the ephemeral argo website. 
- after you have finished testing please remove the commit which changes the `targetRevision` before merging your changes into the `main` branch

## Schemas

We have several Custom Resource Definitions (CRDs) installed in our Kubernetes clusters, and referenced by the Helm charts
in this repository.

We use [kubeconform] to validate our Kubernetes manifests against schemas for
those resources. This helps us ensure that our Helm charts are correct.

`kubeconform` runs in a GitHub Action as a pre-merge check and can also be run
locally.

You can run the validation tests locally by installing `kubeconform` and running

```shell
mkdir helm-dist
for c in charts/*; do
  helm template "$(basename "$c")" "$c" --output-dir helm-dist
done

kubeconform -schema-location default \
-schema-location "https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json" \
-summary helm-dist
```

[kubeconform]: https://github.com/yannh/kubeconform

## Team

[GOV.UK Platform Engineering](https://github.com/orgs/alphagov/teams/gov-uk-platform-engineering) team looks after this repo. If you're inside GDS, you can find us in [#govuk-platform-engineering](https://gds.slack.com/channels/govuk-platform-engineering).

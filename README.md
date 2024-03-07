### Quickstart for local development cluster

This is useful for developing and testing app changes locally, for apps that you are not developing, just copy the image repository and tag from the integration environment to pull down that image.

- use k3d framework

[k3d](https://k3d.io/v5.4.6/) so that we don't need to worry about creating an ingress controller. This will be more aligned with how we run the cluster on EKS as that manages the ingress for us.

  - we will need to create a registry so that we can push locally built images to it and we will want to access it

`k3d cluster create local-ckan --api-port 6550 -p "8081:80@loadbalancer" --registry-create local-registry`

  - before building the image you will need to find the port that the registry is running on 

`docker ps -f name=local-registry`

  - build the docker image with the tag matching the port of the registry

`docker build -t localhost:53492/ckan:2.9.9 -f docker/ckan/2.9.9 .Dockerfile .`

  - NOTE: for Publish and Find build the dev.Dockerfile version

`docker build -t localhost:53492/datagovuk_publish:dev -f docker/dev.Dockerfile .`

  - push the docker image up to your local registry

  `docker push localhost:53492/ckan:2.9.9`

  - update the values.yaml so that the entry in the helm chart for the ckan image should match the registry name and port - 

`image: local-registry:53492/ckan:2.9.9`

- To use a nice url update `/etc/hosts` 

Add `ckan.dev.govuk.digital` and `find.data.gov.uk` after `kubernetes.docker.internal` on the sameline in the `/etc/hosts` file

- Creating the cluster

  - Start by applying `local-dev.yaml`

  `kubectl apply -f local-dev.yaml`

  - Then install the helm chart

  `helm install ckan-dev ./charts/ckan/`

  `helm install datagovuk-dev ./charts/datagovuk/`

  - See the cluster being created and running

  `kubectl get pods`

### Useful tips

### Switching to the local dev cluster

  `kubectl config use-context k3d-local-ckan`

#### How to test chart changes

In order to test the changes in EKS follow these steps:

1. update the `targetRevision` in `ckan-application.yaml` or `datagovuk-application.yaml` to be the branch you want to test against.
1. update the target revision in Argo on `dgu-app-of-apps` to be the branch you want to test, normally on the Integration cluster.
1. carry out your testing.
1. after testing is complete remember to set the target revision back to `main` in `dgu-app-of-apps`.
1. if you are creating a PR drop the commit which updates the `targetRevision` in step 1.

### Github API token permissions

When creating fine-grained API tokens, ensure that read/write permissions for PRs and Content are allowed (this will allow for PR and commit creation) and that CI user is used to create the PRs.

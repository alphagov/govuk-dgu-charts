### Quickstart for local development cluster

- use k3d framework

[k3d](https://k3d.io/v5.4.6/) so that we don't need to worry about creating an ingress controller. This will be more aligned with how we run the cluster on EKS as that manages the ingress for us.

  - we will need to create a registry so that we can push locally built images to it and we will want to access it

`k3d cluster create local-ckan --api-port 6550 -p "8081:80@loadbalancer" --registry-create local-registry`

  - before building the image you will need to find the port that the registry is running on 

`docker ps -f name=local-registry`

  - build the docker image with the tag matching the port of the registry

`docker build -t localhost:53492/ckan:2.9.7 -f Dockerfile .`

  - update the values.yaml so that the entry in the helm chart for the ckan image should match the registry name and port - 

`image: local-registry:53492/ckan:2.9.7`

- To use a nice url update `/etc/hosts` 

Add `ckan.dev.govuk.digital` after kubernetes.docker.internal on the sameline in the `/etc/hosts` file

- Creating the cluster

  - Start by applying `local-dev.yaml`

  `kubectl apply -f local-dev.yaml`

  - Then install the helm chart

  `helm install datagovuk-dev ./charts/datagovuk/`

  - See the cluster being created and running

  `kubectl get pods`

  - Switching to the cluster

  `kubectl config use-context k3d-local-ckan`

### Useful tips

#### How to test chart changes

In order to test the changes in EKS follow these steps:

- disable the auto-sync in the `dgu-app-of-apps` application.
  - edit the target revision to be the branch you want to test and manually sync it.
- edit the revision of the branch to be the branch you want to test in the `ckan` applications (not in the `dgu-app-of-apps` space).
  - you may need to delete the app that has been updated in order to pick up the change.
- if you make further changes to the chart you may need to manually sync the `dgu-app-of-apps`.
- if it is not syncing you may need to check the sync status and terminate any running processes.
- after testing is complete remember to turn on the auto sync in `dgu-app-of-apps`.

### Github API token permissions

When creating fine-grained API tokens, ensure that read/write permissions for PRs and Content are allowed (this will allow for PR and commit creation) and that CI user is used to create the PRs.

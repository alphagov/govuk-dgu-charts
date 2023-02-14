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

Add `dev.data.gov.uk` after kubernetes.docker.internal on the sameline in the `/etc/hosts` file

- Creating the cluster

  - Start by applying `super-secret.yaml`

  `kubectl apply -f super-secret.yaml`

  - Then install the helm chart

  `helm install ckan-test ./charts/ckan/`

  - See the cluster being created and running

  `kubectl get pods`

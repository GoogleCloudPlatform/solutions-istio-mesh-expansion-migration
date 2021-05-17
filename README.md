# Supporting Your Migration with Istio

This solution tutorial demonstrates how to use a service mesh, [Istio](https://istio.io/) to gradually migrate
services from a "legacy" environment to a modern, cloud-native one.

Please refer to the following articles for the steps to run the code:

- [Tutorial](https://cloud.google.com/solutions/supporting-your-migration-with-istio-mesh-expansion-tutorial)
- [Concept](https://cloud.google.com/solutions/supporting-your-migration-with-istio-mesh-expansion-concept)

## Dependencies

For this tutorial, you need the following tools:

- A [POSIX](https://wikipedia.org/wiki/POSIX)-compliant shell.
- [Google Cloud SDK](https://cloud.google.com/sdk) (tested with version `271.0.0`).
- Terraform (tested with version `v0.15.0`), if you prefer provisioning the environment with Terraform.

## Contents of this repository

### Terraform descriptors

The [`terraform`](terraform) directory contains all the [Terraform](https://www.terraform.io/)
descriptors to provision the resources for the tutorial.

### Example Workload

The [Bookinfo app](https://istio.io/docs/examples/bookinfo/) is used as a test workload to gradually migrate to [Kubernetes](https://kubernetes.io/).

It's available for two different deployment methods:

- Docker Compose (in the [`compose`](compose) directory)
- Kubernetes (in the [`kubernetes/bookinfo`](kubernetes/bookinfo) directory)

#### Service Mesh Routing Rules

The [`kubernetes/bookinfo/istio`](kubernetes/bookinfo/istio) directory contains:

- An Istio [Gateway](https://istio.io/docs/reference/config/networking/v1alpha3/gateway/) to expose services
- Istio [ServiceEntries](https://istio.io/docs/reference/config/networking/v1alpha3/service-entry/) to register services running with Docker Compose to the mesh
- Various [VirtualServices](https://istio.io/docs/reference/config/networking/v1alpha3/virtual-service/) to configure routing either to instances running with Docker Compose (`-vm` suffix), to Kubernetes (`-gke` suffix) or to both (`-split` suffix)

### Additional Services

- A Service to expose [KubeDNS](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) so workloads not running in Kubernetes can resolve internal names
- An Istio Gateway and VirtualService to expose Kiali (used to visualize the service mesh)

## Provisioning the environment with Terraform

If you prefer using Terraform to provision the environment for the tutorial, you:

1. Change your working directory to the root of this repository.
1. Initialize the default Google Cloud: `gcloud auth application-default login`
1. Initialize Terraform: `scripts/init.sh`
1. Change your working directory to the `terraform` directory: `cd terraform`
1. Ensure the configuration is valid: `terraform validate`
1. Apply the changes: `terraform apply`

## Deploying workloads

To deploy an example workload in the clusters you create:

1. Change your working directory to the root of this repository.
1. Deploy the workloads: `scripts/workloads.sh`

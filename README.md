# Supporting Your Migration with Istio

This solution tutorial demonstrates how to use a service mesh, [Istio](https://istio.io/) to gradually migrate
services from a "legacy" environment to a modern, cloud-native one.

Please refer to the article for the steps to run the code: [Supporting Your Migration with Istio Mesh Expansion](http://).

## Contents of this repository

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

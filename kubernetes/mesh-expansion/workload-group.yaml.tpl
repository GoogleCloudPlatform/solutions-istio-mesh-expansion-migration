# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
---
apiVersion: networking.istio.io/v1alpha3
kind: WorkloadGroup
metadata:
  name: ${BOOKINFO_COMPONENT_NAME}
  namespace: default
spec:
  metadata:
    labels:
      app: ${BOOKINFO_COMPONENT_NAME}
      app.kubernetes.io/instance: ${BOOKINFO_COMPONENT_NAME}-compute-engine
      app.kubernetes.io/name: ${BOOKINFO_COMPONENT_NAME}
      app.kubernetes.io/version: compute-engine
      instance-id: source-environment-${BOOKINFO_COMPONENT_NAME}
      version: compute-engine
  probe:
    initialDelaySeconds: 5
    timeoutSeconds: 3
    periodSeconds: 4
    successThreshold: 3
    failureThreshold: 3
    httpGet:
      path: /
      port: 9080
      scheme: HTTP
  template:
    labels:
      app: ${BOOKINFO_COMPONENT_NAME}
      app.kubernetes.io/instance: ${BOOKINFO_COMPONENT_NAME}-compute-engine
      app.kubernetes.io/name: ${BOOKINFO_COMPONENT_NAME}
      app.kubernetes.io/version: compute-engine
      instance-id: source-environment-${BOOKINFO_COMPONENT_NAME}
      service.istio.io/canonical-name: ${BOOKINFO_COMPONENT_NAME}
      service.istio.io/canonical-revision: compute-engine
      version: compute-engine
    network: ""
    ports:
      http: 9080
    serviceAccount: bookinfo-gce
...

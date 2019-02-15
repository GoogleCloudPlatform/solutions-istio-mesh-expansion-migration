#!/usr/bin/env bash

# Copyright 2019 Google LLC
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

# Generate a 'kubedns' Dnsmasq config file using the internal load balancer.
# It will need to be installed on each machine expanding the mesh.
NS=${ISTIO_NAMESPACE:-istio-system}

# Multiple tries, it may take some time until the controllers generate the IPs
for _ in {1..20}; do
ISTIO_DNS=$(kubectl get -n kube-system service kube-dns-ilb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
ISTIO_INGRESS_GATEWAY_IP="$(kubectl get -n "$NS" service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
ISTIO_ILB_GATEWAY_IP="$(kubectl get -n "$NS" service istio-ilbgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

if [ "${ISTIO_INGRESS_GATEWAY_IP}" == "" ] || [  "${ISTIO_ILB_GATEWAY_IP}" == "" ] || [  "${ISTIO_DNS}" == "" ]; then
    echo "Waiting for ILBs, ISTIO_INGRESS_GATEWAY_IP=$ISTIO_INGRESS_GATEWAY_IP, ISTIO_ILB_GATEWAY_IP=$ISTIO_ILB_GATEWAY_IP, ISTIO_DNS=${ISTIO_DNS}"
    sleep 30
else
    break
fi
done

if [ "${ISTIO_INGRESS_GATEWAY_IP}" == "" ] || [  "${ISTIO_ILB_GATEWAY_IP}" == "" ] || [  "${ISTIO_DNS}" == "" ]; then
echo "Failed to create ILBs"
exit 1
fi

#/etc/dnsmasq.d/kubedns
{
echo "server=/svc.cluster.local/$ISTIO_DNS"
echo "address=/istio-policy/$ISTIO_INGRESS_GATEWAY_IP"
echo "address=/istio-telemetry/$ISTIO_INGRESS_GATEWAY_IP"
echo "address=/istio-pilot/$ISTIO_ILB_GATEWAY_IP"
echo "address=/istio-citadel/$ISTIO_ILB_GATEWAY_IP"
echo "address=/istio-ca/$ISTIO_ILB_GATEWAY_IP" # Deprecated. For backward compatibility
# Also generate host entries for the istio-system. The generated config will work with both
# 'cluster-wide' and 'per-namespace'.
echo "address=/istio-policy.$NS/$ISTIO_INGRESS_GATEWAY_IP"
echo "address=/istio-telemetry.$NS/$ISTIO_INGRESS_GATEWAY_IP"
echo "address=/istio-pilot.$NS/$ISTIO_ILB_GATEWAY_IP"
echo "address=/istio-citadel.$NS/$ISTIO_ILB_GATEWAY_IP"
echo "address=/istio-ca.$NS/$ISTIO_ILB_GATEWAY_IP" # Deprecated. For backward compatibility
} > kubedns

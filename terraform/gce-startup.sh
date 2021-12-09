#!/usr/bin/env sh

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

set -o nounset
set -o errexit

apt-get update

# Docker installation
apt-get install -y apt-transport-https
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository  "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce

# Ignoring SC2154 because this variable comes from Terraform
# shellcheck disable=SC2154
echo "Installing Docker Compose ${docker_compose_version}"
curl -L https://github.com/docker/compose/releases/download/"${docker_compose_version}"/docker-compose-"$(uname -s)"-"$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Ignoring SC2154 because this variable comes from Terraform
# shellcheck disable=SC2154
echo "Installing Istio ${istio_version} integration runtime..."
curl -LO https://storage.googleapis.com/istio-release/releases/"${istio_version}"/deb/istio-sidecar.deb
dpkg -i istio-sidecar.deb

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

apt-get update

# Docker installation
apt-get install -y apt-transport-https ca-certificates curl dnsmasq resolvconf software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository  "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce

# get latest docker compose released tag
COMPOSE_VERSION="$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)"

curl -L https://github.com/docker/compose/releases/download/"${COMPOSE_VERSION}"/docker-compose-"$(uname -s)"-"$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Bypass systemd-resolved
# Workaround for https://github.com/systemd/systemd/issues/9833
# The issue has been fixed but a new systemd version has not been
# released yet
rm /etc/resolv.conf
ln -s /run/resolvconf/resolv.conf /etc/resolv.conf
systemctl restart resolvconf

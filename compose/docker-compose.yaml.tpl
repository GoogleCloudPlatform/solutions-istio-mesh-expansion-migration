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
---
version: '3'
services:
  ${BOOKINFO_COMPONENT_NAME}:
    environment:
      - DETAILS_HOSTNAME=source-environment-details
      - RATINGS_HOSTNAME=source-environment-ratings
      - REVIEWS_HOSTNAME=source-environment-reviews
      - SERVICES_DOMAIN=${BOOKINFO_COMPONENT_INSTANCE_ZONE}.c.${BOOKINFO_COMPONENT_PROJECT_ID}.internal
    expose:
      - "9080"
    image: ${BOOKINFO_COMPONENT_CONTAINER_IMAGE_TAG}
    network_mode: "host"
...

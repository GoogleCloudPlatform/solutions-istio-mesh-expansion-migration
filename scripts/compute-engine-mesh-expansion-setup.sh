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

# shellcheck disable=SC1091
. scripts/common.sh

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"

DEFAULT_PROJECT_DESCRIPTION="name of the default Google Cloud Project to use"
DEFAULT_REGION_DESCRIPTION="ID of the default Google Cloud Region to use"
DEFAULT_ZONE_DESCRIPTION="ID of the default Google Cloud Zone to use"

usage() {
  echo "${SCRIPT_BASENAME} - This script installs and configures Istio in a Compute Engine instance."
  echo
  echo "USAGE"
  echo "  ${SCRIPT_BASENAME} [options]"
  echo
  echo "OPTIONS"
  echo "  -h $(is_linux && echo "| --help"): ${HELP_DESCRIPTION}"
  echo "  -p $(is_linux && echo "| --default-project"): ${DEFAULT_PROJECT_DESCRIPTION}"
  echo "  -r $(is_linux && echo "| --default-region"): ${DEFAULT_REGION_DESCRIPTION}"
  echo "  -z $(is_linux && echo "| --default-zone"): ${DEFAULT_ZONE_DESCRIPTION}"
  echo
  echo "EXIT STATUS"
  echo
  echo "  ${EXIT_OK} on correct execution."
  echo "  ${ERR_VARIABLE_NOT_DEFINED} when a parameter or a variable is not defined, or empty."
  echo "  ${ERR_MISSING_DEPENDENCY} when a required dependency is missing."
  echo "  ${ERR_ARGUMENT_EVAL_ERROR} when there was an error while evaluating the program options."
}

LONG_OPTIONS="default-project:,default-region:,default-zone:,help"
SHORT_OPTIONS="hp:r:z:"

echo "Checking if the necessary dependencies are available..."
check_exec_dependency "gcloud"
check_exec_dependency "getopt"
check_exec_dependency "kubectl"

# BSD getopt (bundled in MacOS) doesn't support long options, and has different parameters than GNU getopt
if is_linux; then
  TEMP="$(getopt -o "${SHORT_OPTIONS}" --long "${LONG_OPTIONS}" -n "${SCRIPT_BASENAME}" -- "$@")"
elif is_macos; then
  TEMP="$(getopt "${SHORT_OPTIONS} --" "$@")"
fi
RET_CODE=$?
if [ ! $RET_CODE ]; then
  echo "Error while evaluating command options. Terminating..."
  # Ignoring SC2086 because those are defined in common.sh, and don't need quotes
  # shellcheck disable=SC2086
  exit ${ERR_ARGUMENT_EVAL_ERROR}
fi
eval set -- "${TEMP}"

DEFAULT_PROJECT=
DEFAULT_REGION=
DEFAULT_ZONE=

while true; do
  case "${1}" in
  -p | --default-project)
    DEFAULT_PROJECT="${2}"
    shift 2
    ;;
  -r | --default-region)
    DEFAULT_REGION="${2}"
    shift 2
    ;;
  -z | --default-zone)
    DEFAULT_ZONE="${2}"
    shift 2
    ;;
  --)
    shift
    break
    ;;
  -h | --help | *)
    usage
    # Ignoring because those are defined in common.sh, and don't need quotes
    # shellcheck disable=SC2086
    exit ${EXIT_OK}
    break
    ;;
  esac
done

echo "Checking if the necessary parameters are set..."
check_argument "${DEFAULT_REGION}" "${DEFAULT_REGION_DESCRIPTION}"
check_argument "${DEFAULT_ZONE}" "${DEFAULT_ZONE_DESCRIPTION}"
check_argument "${DEFAULT_PROJECT}" "${DEFAULT_PROJECT_DESCRIPTION}"

echo "Setting the default Google Cloud project to ${DEFAULT_PROJECT}..."
gcloud config set project "${DEFAULT_PROJECT}"

echo "Setting the default Compute region to ${DEFAULT_REGION}..."
gcloud config set compute/region "${DEFAULT_REGION}"

echo "Setting the default Compute zone to ${DEFAULT_ZONE}..."
gcloud config set compute/zone "${DEFAULT_ZONE}"

echo "Exposing Istio control plane services..."
kubectl apply -n istio-system -f "${ISTIO_SAMPLES_PATH}"/multicluster/expose-istiod.yaml

echo "Creating the Kubernetes service account for the Compute Engine instance..."
kubectl apply -f "${MESH_EXPANSION_DIRECTORY_PATH}"/gce-service-account.yaml

MESH_EXPANSION_ROOT_CONFIG_DESTINATION_PATH=/tmp/mesh-expansion/config

for component in ${BOOKINFO_COMPONENTS}; do
  BOOKINFO_COMPONENT_NAME="${component}"
  export BOOKINFO_COMPONENT_NAME

  BOOKINFO_COMPONENT_CONFIG_DIRECTORY="${MESH_EXPANSION_DIRECTORY_PATH}"/config/"${component}"
  echo "Creating mesh expansion configuration files for ${BOOKINFO_COMPONENT_NAME} in ${BOOKINFO_COMPONENT_CONFIG_DIRECTORY}..."
  mkdir -p "${BOOKINFO_COMPONENT_CONFIG_DIRECTORY}"

  WORKLOAD_GROUP_PATH="${BOOKINFO_COMPONENT_CONFIG_DIRECTORY}"/workload-group.yaml
  envsubst < "${WORKLOAD_GROUP_TEMPLATE_PATH}" > "${WORKLOAD_GROUP_PATH}"
  "${ISTIO_BIN_PATH}"/istioctl x workload entry configure -f "${WORKLOAD_GROUP_PATH}" -o "${BOOKINFO_COMPONENT_CONFIG_DIRECTORY}" --clusterID "Kubernetes"

  # Workaround for https://github.com/istio/istio/issues/33225
  find "${BOOKINFO_COMPONENT_CONFIG_DIRECTORY}" -type f -exec sed -i 's/"\[{\\"name\\":\\"http\\",\\"containerPort\\":9080,\\"protocol\\":\\"\\"}\]"/[{"name":"http","containerPort":9080,"protocol":""}]/g' {} +

  BOOKINFO_COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME="${GCE_INSTANCE_NAME_PREFIX}${BOOKINFO_COMPONENT_NAME}"
  BOOKINFO_COMPONENT_COMPUTE_ENGINE_INSTANCE_IP_ADDRESS="$(gcloud compute instances describe "${BOOKINFO_COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME}" --format='value(networkInterfaces[0].accessConfigs[0].natIP)')"
  export BOOKINFO_COMPONENT_COMPUTE_ENGINE_INSTANCE_IP_ADDRESS

  WORKLOAD_ENTRY_PATH="${BOOKINFO_COMPONENT_CONFIG_DIRECTORY}"/workload-entry.yaml
  envsubst < "${WORKLOAD_ENTRY_TEMPLATE_PATH}" > "${WORKLOAD_ENTRY_PATH}"

  COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME="${GCE_INSTANCE_NAME_PREFIX}${BOOKINFO_COMPONENT_NAME}"

  MESH_EXPANSION_CONFIG_DIRECTORY_SOURCE_PATH="${CURRENT_WORKING_DIRECTORY}"/kubernetes/mesh-expansion/config/"${BOOKINFO_COMPONENT_NAME}"

  echo "Copying mesh expansion configuration files from ${MESH_EXPANSION_CONFIG_DIRECTORY_SOURCE_PATH} to the ${COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME} instance..."
  MESH_EXPANSION_CONFIG_DESTINATION_PATH="${MESH_EXPANSION_ROOT_CONFIG_DESTINATION_PATH}"/"${BOOKINFO_COMPONENT_NAME}"
  gcloud compute ssh "${COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME}" \
    --command="mkdir -p ${MESH_EXPANSION_CONFIG_DESTINATION_PATH}"
  gcloud compute scp --recurse \
    "${MESH_EXPANSION_CONFIG_DIRECTORY_SOURCE_PATH}" \
    "${COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME}":"${MESH_EXPANSION_ROOT_CONFIG_DESTINATION_PATH}"
  
  echo "Placing Istio configuration files in the expected places on the ${COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME} instance..."
  gcloud compute ssh "${COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME}" \
    --command="sudo mkdir -p /etc/certs \
      && sudo cp ${MESH_EXPANSION_CONFIG_DESTINATION_PATH}/root-cert.pem /etc/certs/root-cert.pem \
      && sudo mkdir -p /var/run/secrets/tokens \
      && sudo cp ${MESH_EXPANSION_CONFIG_DESTINATION_PATH}/istio-token /var/run/secrets/tokens/istio-token \
      && sudo cp ${MESH_EXPANSION_CONFIG_DESTINATION_PATH}/cluster.env /var/lib/istio/envoy/cluster.env \
      && sudo cp ${MESH_EXPANSION_CONFIG_DESTINATION_PATH}/mesh.yaml /etc/istio/config/mesh \
      && sudo mkdir -p /etc/istio/proxy \
      && sudo chown -R istio-proxy /var/lib/istio /etc/certs /etc/istio/proxy /etc/istio/config /var/run/secrets /etc/certs/root-cert.pem"
  
  echo "Adding the istiod host to /etc/hosts on the ${COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME} instance..."
  # Ignoring because we want the substituiton to happen in the target shell
  # shellcheck disable=SC2016
  gcloud compute ssh "${COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME}" \
    --command="sudo sh -c 'cat ${MESH_EXPANSION_CONFIG_DESTINATION_PATH}/hosts >> /etc/hosts'"

  echo "Starting the Istio agent in the ${COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME} instance..."
  gcloud compute ssh "${COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME}" \
    --command="sudo rm -f /var/log/istio/istio.* && sudo systemctl stop istio && sudo systemctl start istio"
done

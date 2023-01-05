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

COMPOSE_SELECTOR="COMPOSE"
GKE_SELECTOR="GKE"
GKE_ONLY_SELECTOR="GKE_ONLY"
REMOVE_NON_GKE_SELECTOR="${GKE_ONLY_SELECTOR}"

ISTIO_GCE_DESCRIPTOR="ISTIO_COMPUTE_ENGINE"

DEPLOY_WITH_DESCRIPTION="What to use to deploy workloads. Allowed values: ${COMPOSE_SELECTOR} (deploy with Docker Compose), ${GKE_SELECTOR} (deploy with GKE), ${REMOVE_NON_GKE_SELECTOR} (remove instances running outside GKE)"
EXPOSE_WITH_DESCRIPTION="What to use to expoose workloads. Allowed values: ${ISTIO_GCE_DESCRIPTOR} (expose workloads running in Compute Engine using Istio running in GKE), ${GKE_ONLY_SELECTOR} (expose only the workloads running in GKE using Istio)"
DEFAULT_PROJECT_DESCRIPTION="name of the default Google Cloud Project to use"
DEFAULT_REGION_DESCRIPTION="ID of the default Google Cloud Region to use"
DEFAULT_ZONE_DESCRIPTION="ID of the default Google Cloud Zone to use"

usage() {
  echo "${SCRIPT_BASENAME} - This script deploys workloads."
  echo
  echo "USAGE"
  echo "  ${SCRIPT_BASENAME} [options]"
  echo
  echo "OPTIONS"
  echo "  -d $(is_linux && echo "| --deploy-with"): ${DEPLOY_WITH_DESCRIPTION}"
  echo "  -e $(is_linux && echo "| --expose-with"): ${EXPOSE_WITH_DESCRIPTION}"
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

LONG_OPTIONS="deploy-with:,default-project:,default-region:,default-zone:,expose-with:,help"
SHORT_OPTIONS="d:e:hp:r:z:"

echo "Checking if the necessary dependencies are available..."
check_exec_dependency "envsubst"
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

DEPLOY_WITH=
DEFAULT_PROJECT=
DEFAULT_REGION=
DEFAULT_ZONE=
EXPOSE_WITH=

while true; do
  case "${1}" in
  -d | --deploy-with)
    DEPLOY_WITH="${2}"
    shift 2
    ;;
  -e | --expose-with)
    EXPOSE_WITH="${2}"
    shift 2
    ;;
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

SERVICE_NAMESPACE=default
COMPOSE_DESCRIPTOR_DESTINATION_DIRECTORY_PATH=/tmp/compose

if [ "${DEPLOY_WITH}" = "${COMPOSE_SELECTOR}" ]; then
  echo "Deploying workloads with ${COMPOSE_SELECTOR}..."

  TUTORIAL_COMPOSE_DESCRIPTORS_PATH="${CURRENT_WORKING_DIRECTORY}"/compose
  TUTORIAL_COMPOSE_DESCRIPTOR_TEMPLATE_PATH="${TUTORIAL_COMPOSE_DESCRIPTORS_PATH}"/docker-compose.yaml.tpl

  for component in ${BOOKINFO_COMPONENTS}; do
    BOOKINFO_COMPONENT_NAME="${component}"
    export BOOKINFO_COMPONENT_NAME

    COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME="${GCE_INSTANCE_NAME_PREFIX}${BOOKINFO_COMPONENT_NAME}"

    BOOKINFO_COMPONENT_PROJECT_ID="${DEFAULT_PROJECT}"
    export BOOKINFO_COMPONENT_PROJECT_ID

    BOOKINFO_COMPONENT_INSTANCE_ZONE="${DEFAULT_ZONE}"
    export BOOKINFO_COMPONENT_INSTANCE_ZONE

    CONTAINER_IMAGE_SUFFIX="v1"
    if [ "${BOOKINFO_COMPONENT_NAME}" = "reviews" ]; then
      CONTAINER_IMAGE_SUFFIX="v3"
    fi

    BOOKINFO_COMPONENT_CONTAINER_IMAGE_TAG="istio/examples-bookinfo-${BOOKINFO_COMPONENT_NAME}-${CONTAINER_IMAGE_SUFFIX}:1.16.2"
    export BOOKINFO_COMPONENT_CONTAINER_IMAGE_TAG

    COMPONENT_COMPOSE_DESCRIPTOR_NAME=docker-compose-"${component}".yaml
    COMPONENT_COMPOSE_DESCRIPTOR_PATH="${TUTORIAL_COMPOSE_DESCRIPTORS_PATH}"/"${COMPONENT_COMPOSE_DESCRIPTOR_NAME}"
    envsubst < "${TUTORIAL_COMPOSE_DESCRIPTOR_TEMPLATE_PATH}" > "${COMPONENT_COMPOSE_DESCRIPTOR_PATH}"

    echo "Copying Docker Compose descriptors to the ${COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME} instance..."
    COMPOSE_DESCRIPTOR_DESTINATION_PATH="${COMPOSE_DESCRIPTOR_DESTINATION_DIRECTORY_PATH}"/"${COMPONENT_COMPOSE_DESCRIPTOR_NAME}"
    gcloud compute ssh "${COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME}" \
      --command='mkdir -p /tmp/compose'
    gcloud compute scp \
      "${COMPONENT_COMPOSE_DESCRIPTOR_PATH}" \
      "${COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME}":"${COMPOSE_DESCRIPTOR_DESTINATION_PATH}"

    echo "Waiting for Docker Compose to be available in the ${COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME} instance..."
    gcloud compute ssh "${COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME}" \
      --command='while ! command -v docker-compose; do echo "Waiting for docker-compose to be installed"; sleep 5; done'

    echo "Deploying the workload to the ${COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME} instance..."
    gcloud compute ssh "${COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME}" \
      --command="sudo docker-compose -f ${COMPOSE_DESCRIPTOR_DESTINATION_PATH} up --detach --remove-orphans"
  done

  PRODUCTPAGE_COMPUTE_ENGINE_INSTANCE_IP_ADDRESS="$(gcloud compute instances describe source-environment-productpage --format='value(networkInterfaces[0].accessConfigs[0].natIP)')"
  echo "You can access the workload by loading http://${PRODUCTPAGE_COMPUTE_ENGINE_INSTANCE_IP_ADDRESS}:9080/productpage"
elif [ "${DEPLOY_WITH}" = "${GKE_SELECTOR}" ]; then
  echo "Deploying workloads with ${GKE_SELECTOR}..."

  echo "Enabling automatic sidecar injection for the ${SERVICE_NAMESPACE} namespace..."
  kubectl label --overwrite namespace "${SERVICE_NAMESPACE}" istio-injection=enabled

  for component in ${BOOKINFO_COMPONENTS}; do
    if [ "${component}" = "reviews" ]; then
      COMPONENT_VERSION="v3"
    else
      COMPONENT_VERSION="v1"
    fi

    echo "Deploying ${component}, version: ${COMPONENT_VERSION}"
    kubectl apply -f "${ISTIO_SAMPLES_PATH}"/bookinfo/platform/kube/bookinfo.yaml -l "account=${component}"
    kubectl apply -f "${ISTIO_SAMPLES_PATH}"/bookinfo/platform/kube/bookinfo.yaml -l "app=${component},version=${COMPONENT_VERSION}"
  done

  unset COMPONENT_VERSION

  print_workload_access_information
elif [ "${DEPLOY_WITH}" = "${GKE_ONLY_SELECTOR}" ]; then
  echo "Deploy workloads with ${GKE_ONLY_SELECTOR}..."
  echo "Removing workloads running outside GKE..."

  for component in ${BOOKINFO_COMPONENTS}; do
    BOOKINFO_COMPONENT_NAME="${component}"
    COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME="${GCE_INSTANCE_NAME_PREFIX}${BOOKINFO_COMPONENT_NAME}"
    COMPONENT_COMPOSE_DESCRIPTOR_NAME=docker-compose-"${component}".yaml

    COMPOSE_DESCRIPTOR_DESTINATION_PATH="${COMPOSE_DESCRIPTOR_DESTINATION_DIRECTORY_PATH}"/"${COMPONENT_COMPOSE_DESCRIPTOR_NAME}"

    echo "Stopping ${component} running in the ${COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME} Compute Engine instance (Docker Compose config file: ${COMPOSE_DESCRIPTOR_DESTINATION_PATH})..."
    gcloud compute ssh "${COMPONENT_COMPUTE_ENGINE_INSTANCE_NAME}" \
      --command="sudo docker-compose -f ${COMPOSE_DESCRIPTOR_DESTINATION_PATH} down --remove-orphans"
  done
elif [ -n "${DEPLOY_WITH}" ]; then
  echo "ERROR: DEPLOY_WITH (set to: ${DEPLOY_WITH}) doesn't match any of the known values. Terminating..."
  # Ignoring SC2086 because those are defined in common.sh, and don't need quotes
  # shellcheck disable=SC2086
  exit ${ERR_ARGUMENT_EVAL_ERROR}
fi

if [ "${EXPOSE_WITH}" = "${ISTIO_GCE_DESCRIPTOR}" ]; then
  echo "Exposing workloads with ${ISTIO_GCE_DESCRIPTOR}..."

  for component in ${BOOKINFO_COMPONENTS}; do
    BOOKINFO_COMPONENT_CONFIG_DIRECTORY="${MESH_EXPANSION_DIRECTORY_PATH}"/config/"${component}"
    WORKLOAD_ENTRY_PATH="${BOOKINFO_COMPONENT_CONFIG_DIRECTORY}"/workload-entry.yaml

    echo "Deploying WorkloadEntries in the ${SERVICE_NAMESPACE} to register the ${component} workload running in the Compute Engine instance..."
    kubectl apply -f "${WORKLOAD_ENTRY_PATH}" -n "${SERVICE_NAMESPACE}"

    echo "Deploying Services in the ${SERVICE_NAMESPACE} to expose the WorkloadEntries..."
    kubectl apply -f "${ISTIO_SAMPLES_PATH}"/bookinfo/platform/kube/bookinfo.yaml -l "service=${component}"
  done

  echo "Deploying ServiceEntries in the ${SERVICE_NAMESPACE} to allow traffic to the Compute Engine metadata server and to Google Cloud APIs..."
  kubectl apply -f "${TUTORIAL_KUBERNETES_DESCRIPTORS_PATH}"/bookinfo/istio/service-entry.yaml -n "${SERVICE_NAMESPACE}"

  echo "Deploying VirtualServices in the ${SERVICE_NAMESPACE} to allow routing traffic to the workloads running in the Compute Engine instance..."
  kubectl apply -f "${TUTORIAL_KUBERNETES_DESCRIPTORS_PATH}"/bookinfo/istio/virtualservice-vm.yaml -n "${SERVICE_NAMESPACE}"

  print_workload_access_information
elif [ "${EXPOSE_WITH}" = "${GKE_ONLY_SELECTOR}" ]; then
  echo "Exposing workloads with ${GKE_ONLY_SELECTOR}..."

  for component in ${BOOKINFO_COMPONENTS}; do
    BOOKINFO_COMPONENT_CONFIG_DIRECTORY="${MESH_EXPANSION_DIRECTORY_PATH}"/config/"${component}"
    WORKLOAD_ENTRY_PATH="${BOOKINFO_COMPONENT_CONFIG_DIRECTORY}"/workload-entry.yaml

    echo "Removing WorkloadEntries in the ${SERVICE_NAMESPACE} to unregister the ${component} workload running in the Compute Engine instance..."
    kubectl delete -f "${WORKLOAD_ENTRY_PATH}" -n "${SERVICE_NAMESPACE}"
  done

  print_workload_access_information
elif [ -n "${EXPOSE_WITH}" ]; then
  echo "ERROR: ${EXPOSE_WITH} doesn't match any of the known values. Terminating..."
  # Ignoring SC2086 because those are defined in common.sh, and don't need quotes
  # shellcheck disable=SC2086
  exit ${ERR_ARGUMENT_EVAL_ERROR}
fi

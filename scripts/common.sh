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

# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
EXIT_OK=0
EXIT_GENERIC_ERR=1
ERR_VARIABLE_NOT_DEFINED=2
ERR_MISSING_DEPENDENCY=3
# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ERR_ARGUMENT_EVAL_ERROR=4
# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ERR_GOOGLE_APPLICATION_CREDENTIALS_NOT_FOUND=5
# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ERR_DIRECTORY_NOT_FOUND=6

# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
HELP_DESCRIPTION="show this help message and exit"

CURRENT_WORKING_DIRECTORY="$(pwd)"

ISTIO_VERSION="1.10.1"

ISTIO_PATH="${CURRENT_WORKING_DIRECTORY}"/istio-"${ISTIO_VERSION}"

# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ISTIO_BIN_PATH="${ISTIO_PATH}"/bin

# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ISTIO_SAMPLES_PATH="${ISTIO_PATH}"/samples

# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
BOOKINFO_COMPONENTS="productpage details reviews ratings"

# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
GCE_INSTANCE_NAME_PREFIX="source-environment-"

# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
TUTORIAL_KUBERNETES_DESCRIPTORS_PATH="${CURRENT_WORKING_DIRECTORY}"/kubernetes

MESH_EXPANSION_DIRECTORY_PATH="${TUTORIAL_KUBERNETES_DESCRIPTORS_PATH}"/mesh-expansion

# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
WORKLOAD_GROUP_TEMPLATE_PATH="${MESH_EXPANSION_DIRECTORY_PATH}"/workload-group.yaml.tpl

# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
WORKLOAD_ENTRY_TEMPLATE_PATH="${MESH_EXPANSION_DIRECTORY_PATH}"/workload-entry.yaml.tpl

check_argument() {
  ARGUMENT_VALUE="${1}"
  ARGUMENT_DESCRIPTION="${2}"

  if [ -z "${ARGUMENT_VALUE}" ]; then
    echo "[ERROR]: ${ARGUMENT_DESCRIPTION} is not defined. Run this command with the -h option to get help. Terminating..."
    exit ${ERR_VARIABLE_NOT_DEFINED}
  else
    echo "[OK]: ${ARGUMENT_DESCRIPTION} value is defined: ${ARGUMENT_VALUE}"
  fi

  unset ARGUMENT_NAME
  unset ARGUMENT_VALUE
}

check_optional_argument() {
  ARGUMENT_VALUE="${1}"
  ARGUMENT_DESCRIPTION="${2}"

  if [ -z "${ARGUMENT_VALUE}" ]; then
    echo "[OK]: optional ${ARGUMENT_DESCRIPTION} is not defined."
  else
    echo "[OK]: optional ${ARGUMENT_DESCRIPTION} value is defined: ${ARGUMENT_VALUE}"
  fi

  unset ARGUMENT_NAME
  unset ARGUMENT_VALUE
}

check_exec_dependency() {
  EXECUTABLE_NAME="${1}"

  if ! command -v "${EXECUTABLE_NAME}" >/dev/null 2>&1; then
    echo "[ERROR]: ${EXECUTABLE_NAME} command is not available, but it's needed. Make it available in PATH and try again. Terminating..."
    exit ${ERR_MISSING_DEPENDENCY}
  else
    echo "[OK]: ${EXECUTABLE_NAME} is available in PATH, pointing to: $(command -v "${EXECUTABLE_NAME}")"
  fi

  unset EXECUTABLE_NAME
}

print_workload_access_information() {
  ISTIO_INGRESS_GATEWAY_IP_ADDRESS="$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
  echo "You can access the workload by loading http://${ISTIO_INGRESS_GATEWAY_IP_ADDRESS}/productpage"
}

is_linux() {
  os_name="$(uname -s)"
  if test "${os_name#*"Linux"}" != "$os_name"; then
    unset os_name
    return ${EXIT_OK}
  else
    unset os_name
    return ${EXIT_GENERIC_ERR}
  fi
}

is_macos() {
  os_name="$(uname -s)"
  if test "${os_name#*"Darwin"}" != "$os_name"; then
    unset os_name
    return 0
  else
    unset os_name
    return ${EXIT_GENERIC_ERR}
  fi
}

wait_for_load_balancer_ip() {
  LOAD_BALANCER_NAME="${1}"
  LOAD_BALANCER_NAMESPACE="${2}"
  LOAD_BALANCER_IP_ADDRESS=""
  while [ -z "${LOAD_BALANCER_IP_ADDRESS}" ]; do
    echo "Waiting for the ${LOAD_BALANCER_NAMESPACE}/${LOAD_BALANCER_NAME} load balancer to get an external IP address..."
    LOAD_BALANCER_IP_ADDRESS=$(kubectl get svc "${LOAD_BALANCER_NAME}" --namespace "${LOAD_BALANCER_NAMESPACE}" --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
    [ -z "${LOAD_BALANCER_IP_ADDRESS}" ] && sleep 10
  done
  echo "The ${LOAD_BALANCER_NAMESPACE}/${LOAD_BALANCER_NAME} load balancer got an external IP address: ${LOAD_BALANCER_IP_ADDRESS}"
  unset LOAD_BALANCER_IP_ADDRESS
  return 0
}

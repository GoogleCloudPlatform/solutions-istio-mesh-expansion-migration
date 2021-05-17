#!/usr/bin/env sh

set -o nounset
set -o errexit

# shellcheck disable=SC1091
. scripts/common.sh

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"

COMPUTE_ENGINE_INSTANCE_NAME_DESCRIPTION="Name of the Compute Engine instance to deploy to"
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
  echo "  -c $(is_linux && echo "| --compute-engine-instance-name"): ${COMPUTE_ENGINE_INSTANCE_NAME_DESCRIPTION}"
  echo "  -h $(is_linux && echo "| --help"): ${HELP_DESCRIPTION}"
  echo "  -p $(is_linux && echo "| --default-project"): ${DEFAULT_PROJECT_DESCRIPTION}"
  echo "  -r $(is_linux && echo "| --default-region"): ${DEFAULT_REGION_DESCRIPTION}"
  echo "  -z $(is_linux && echo "| --default-zone"): ${DEFAULT_ZONE_DESCRIPTION}"
  echo
  echo "EXIT STATUS"
  echo
  echo "  $EXIT_OK on correct execution."
  echo "  $ERR_VARIABLE_NOT_DEFINED when a parameter or a variable is not defined, or empty."
  echo "  $ERR_MISSING_DEPENDENCY when a required dependency is missing."
  echo "  $ERR_ARGUMENT_EVAL_ERROR when there was an error while evaluating the program options."
}

LONG_OPTIONS="compute-engine-instance-name:,default-project:,default-region:,default-zone:,help"
SHORT_OPTIONS="c:hp:r:z:"

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

COMPUTE_ENGINE_INSTANCE_NAME=
DEFAULT_PROJECT=
DEFAULT_REGION=
DEFAULT_ZONE=

while true; do
  case "${1}" in
  -c | --compute-engine-instance-name)
    COMPUTE_ENGINE_INSTANCE_NAME="${2}"
    shift 2
    ;;
  -d | --deploy-with)
    DEPLOY_WITH="${2}"
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
    exit $EXIT_OK
    break
    ;;
  esac
done

echo "Checking if the necessary parameters are set..."
check_argument "${COMPUTE_ENGINE_INSTANCE_NAME}" "${COMPUTE_ENGINE_INSTANCE_NAME_DESCRIPTION}"
check_argument "${DEFAULT_REGION}" "${DEFAULT_REGION_DESCRIPTION}"
check_argument "${DEFAULT_ZONE}" "${DEFAULT_ZONE_DESCRIPTION}"
check_argument "${DEFAULT_PROJECT}" "${DEFAULT_PROJECT_DESCRIPTION}"

echo "Setting the default Google Cloud project to ${DEFAULT_PROJECT}..."
gcloud config set project "${DEFAULT_PROJECT}"

echo "Setting the default Compute region to ${DEFAULT_REGION}..."
gcloud config set compute/region "${DEFAULT_REGION}"

echo "Setting the default Compute zone to ${DEFAULT_ZONE}..."
gcloud config set compute/zone "${DEFAULT_ZONE}"

MESH_EXPANSION_CONFIG_DIRECTORY_PATH=/tmp/mesh-expansion
gcloud compute ssh "${COMPUTE_ENGINE_INSTANCE_NAME}" \
  --command="mkdir ${MESH_EXPANSION_CONFIG_DIRECTORY_PATH}"

echo "Copying mesh expansion configuration files to the ${COMPUTE_ENGINE_INSTANCE_NAME} instance..."
gcloud compute scp --recurse \
  "${TUTORIAL_COMPOSE_DESCRIPTORS_PATH}" \
  "${COMPUTE_ENGINE_INSTANCE_NAME}":"${MESH_EXPANSION_CONFIG_DIRECTORY_PATH}"

echo "Configuring mesh expansion..."
gcloud compute ssh "${COMPUTE_ENGINE_INSTANCE_NAME}" \
  --command="sudo mkdir -p /etc/certs \
    && sudo cp ${MESH_EXPANSION_CONFIG_DIRECTORY_PATH}/root-cert.pem /etc/certs/root-cert.pem \
    && sudo mkdir -p /var/run/secrets/tokens \
    && sudo cp ${MESH_EXPANSION_CONFIG_DIRECTORY_PATH}/istio-token /var/run/secrets/tokens/istio-token \
    && sudo cp ${MESH_EXPANSION_CONFIG_DIRECTORY_PATH}/cluster.env /var/lib/istio/envoy/cluster.env \
    && sudo cp ${MESH_EXPANSION_CONFIG_DIRECTORY_PATH}/mesh.yaml /etc/istio/config/mesh \
    && sudo mkdir -p /etc/istio/proxy \
    && sudo chown -R istio-proxy /var/lib/istio /etc/certs /etc/istio/proxy /etc/istio/config /var/run/secrets /etc/certs/root-cert.pem
  "

# Ignoring because we want the substituiton to happen in the target shell
# shellcheck disable=SC2016
gcloud compute ssh "${COMPUTE_ENGINE_INSTANCE_NAME}" \
  --command='sudo sh -c "cat $(eval echo ~$SUDO_USER)/hosts >> /etc/hosts'

echo "Starting the Istio agent in the Compute Engine instance..."
gcloud compute ssh "${COMPUTE_ENGINE_INSTANCE_NAME}" \
  --command="sudo systemctl start istio"

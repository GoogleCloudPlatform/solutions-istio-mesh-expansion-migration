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

GOOGLE_APPLICATION_CREDENTIALS_DESCRIPTION="path to the Application Credentials. See gcloud auth application-default login"
GOOGLE_CLOUD_BILLING_ACCOUNT_ID_DESCRIPTION="ID of the billing account to use"
GOOGLE_CLOUD_DEFAULT_FOLDER_DESCRIPTION="ID of the Google Cloud Folder to use"
GOOGLE_CLOUD_DEFAULT_PROJECT_DESCRIPTION="name of the default Google Cloud Project to use"
GOOGLE_CLOUD_DEFAULT_REGION_DESCRIPTION="ID of the default Google Cloud Region to use"
GOOGLE_CLOUD_DEFAULT_ZONE_DESCRIPTION="ID of the default Google Cloud Zone to use"
ORGANIZATION_ID_DESCRIPTION="ID of the Google Cloud Organization"

usage() {
  echo
  echo "${SCRIPT_BASENAME} - This script initializes the environment for Terraform."
  echo
  echo "USAGE"
  echo "  ${SCRIPT_BASENAME} [options]"
  echo
  echo "OPTIONS"
  echo "  -b $(is_linux && echo "| --billing-account-id"): ${GOOGLE_CLOUD_BILLING_ACCOUNT_ID_DESCRIPTION}"
  echo "  -c $(is_linux && echo "| --application-credentials"): ${GOOGLE_APPLICATION_CREDENTIALS_DESCRIPTION}"
  echo "  -f $(is_linux && echo "| --default-folder"): ${GOOGLE_CLOUD_DEFAULT_FOLDER_DESCRIPTION}"
  echo "  -h $(is_linux && echo "| --help"): ${HELP_DESCRIPTION}"
  echo "  -o $(is_linux && echo "| --organization-id"): ${ORGANIZATION_ID_DESCRIPTION}"
  echo "  -p $(is_linux && echo "| --default-project"): ${GOOGLE_CLOUD_DEFAULT_PROJECT_DESCRIPTION}"
  echo "  -r $(is_linux && echo "| --default-region"): ${GOOGLE_CLOUD_DEFAULT_REGION_DESCRIPTION}"
  echo "  -z $(is_linux && echo "| --default-zone"): ${GOOGLE_CLOUD_DEFAULT_ZONE_DESCRIPTION}"
  echo
  echo "EXIT STATUS"
  echo
  echo "  ${EXIT_OK} on correct execution."
  echo "  ${ERR_VARIABLE_NOT_DEFINED} when a parameter or a variable is not defined, or empty."
  echo "  ${ERR_MISSING_DEPENDENCY} when a required dependency is missing."
  echo "  ${ERR_ARGUMENT_EVAL_ERROR} when there was an error while evaluating the program options."
}

LONG_OPTIONS="application-credentials:,billing-account-id:,default-folder:,default-project:,default-region:,default-zone:,help,,organization-id:"
SHORT_OPTIONS="b:c:f:ho:p:r:z:"

echo "Checking if the necessary dependencies are available..."
check_exec_dependency "gcloud"
check_exec_dependency "getopt"
check_exec_dependency "gsutil"
check_exec_dependency "terraform"

# BSD getopt (bundled in MacOS) doesn't support long options, and has different parameters than GNU getopt
if is_linux; then
  TEMP="$(getopt -o "${SHORT_OPTIONS}" --long "${LONG_OPTIONS}" -n "${SCRIPT_BASENAME}" -- "$@")"
elif is_macos; then
  TEMP="$(getopt "${SHORT_OPTIONS} --" "$@")"
fi
RET_CODE=$?
if [ ! ${RET_CODE} ]; then
  echo "Error while evaluating command options. Terminating..."
  # Ignoring SC2086 because those are defined in common.sh, and don't need quotes
  # shellcheck disable=SC2086
  exit ${ERR_ARGUMENT_EVAL_ERROR}
fi
eval set -- "${TEMP}"

GOOGLE_APPLICATION_CREDENTIALS=
GOOGLE_CLOUD_BILLING_ACCOUNT_ID=
GOOGLE_CLOUD_DEFAULT_FOLDER=""
GOOGLE_CLOUD_DEFAULT_PROJECT=
GOOGLE_CLOUD_DEFAULT_REGION=
GOOGLE_CLOUD_DEFAULT_ZONE=
ORGANIZATION_ID=

while true; do
  case "${1}" in
  -b | --billing-account-id)
    GOOGLE_CLOUD_BILLING_ACCOUNT_ID="${2}"
    shift 2
    ;;
  -c | --application-credentials)
    GOOGLE_APPLICATION_CREDENTIALS="${2}"
    shift 2
    ;;
  -f | --default-folder)
    GOOGLE_CLOUD_DEFAULT_FOLDER="${2}"
    shift 2
    ;;
  -o | --organization-id)
    ORGANIZATION_ID="${2}"
    shift 2
    ;;
  -p | --default-project)
    GOOGLE_CLOUD_DEFAULT_PROJECT="${2}"
    shift 2
    ;;
  -r | --default-region)
    GOOGLE_CLOUD_DEFAULT_REGION="${2}"
    shift 2
    ;;
  -z | --default-zone)
    GOOGLE_CLOUD_DEFAULT_ZONE="${2}"
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
check_argument "${GOOGLE_APPLICATION_CREDENTIALS}" "${GOOGLE_APPLICATION_CREDENTIALS_DESCRIPTION}"
check_argument "${GOOGLE_CLOUD_BILLING_ACCOUNT_ID}" "${GOOGLE_CLOUD_BILLING_ACCOUNT_ID_DESCRIPTION}"
check_argument "${GOOGLE_CLOUD_DEFAULT_PROJECT}" "${GOOGLE_CLOUD_DEFAULT_PROJECT_DESCRIPTION}"
check_argument "${GOOGLE_CLOUD_DEFAULT_REGION}" "${GOOGLE_CLOUD_DEFAULT_REGION_DESCRIPTION}"
check_argument "${GOOGLE_CLOUD_DEFAULT_ZONE}" "${GOOGLE_CLOUD_DEFAULT_ZONE_DESCRIPTION}"
check_argument "${ORGANIZATION_ID}" "${ORGANIZATION_ID_DESCRIPTION}"

check_optional_argument "${GOOGLE_CLOUD_DEFAULT_FOLDER}" "${GOOGLE_CLOUD_DEFAULT_FOLDER_DESCRIPTION}"

if [ ! -e "${GOOGLE_APPLICATION_CREDENTIALS}" ]; then
  echo "ERROR: Cannot find the Google Application Credentials file (${GOOGLE_APPLICATION_CREDENTIALS}). Terminating..."
  # Ignoring because those are defined in common.sh, and don't need quotes
  # shellcheck disable=SC2086
  exit ${ERR_GOOGLE_APPLICATION_CREDENTIALS_NOT_FOUND}
fi

REPO_DIRECTORY="$(pwd)"

TERRAFORM_ENVIRONMENT_DIR="${REPO_DIRECTORY}/terraform"

TERRAFORM_TFVARS_PATH="${TERRAFORM_ENVIRONMENT_DIR}/terraform.tfvars"
echo "Generating ${TERRAFORM_TFVARS_PATH}..."
if [ -f "${TERRAFORM_TFVARS_PATH}" ]; then
  echo "[ERROR]: The ${TERRAFORM_TFVARS_PATH} file already exists. Delete it before generating a new one. Terminating..."
  # Ignoring because those are defined in common.sh, and don't need quotes
  # shellcheck disable=SC2086
  exit ${ERR_ARGUMENT_EVAL_ERROR}
else
  tee "${TERRAFORM_TFVARS_PATH}" <<EOF
google_billing_account_id = "${GOOGLE_CLOUD_BILLING_ACCOUNT_ID}"
google_default_project_id = "${GOOGLE_CLOUD_DEFAULT_PROJECT}"
google_default_region     = "${GOOGLE_CLOUD_DEFAULT_REGION}"
google_default_zone       = "${GOOGLE_CLOUD_DEFAULT_ZONE}"
google_folder_id          = "${GOOGLE_CLOUD_DEFAULT_FOLDER}"
google_organization_id    = "${ORGANIZATION_ID}"
istio_version             = "${ISTIO_VERSION}"
EOF
fi

echo "Changing the working directory to ${TERRAFORM_ENVIRONMENT_DIR}..."
cd "${TERRAFORM_ENVIRONMENT_DIR}"

echo "Initializing Terraform..."
terraform init

echo "Validating Terraform descriptors..."
terraform validate

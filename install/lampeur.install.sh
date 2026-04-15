#!/bin/bash

MAIN_SCRIPT_PATH="$(readlink -f "${0}")"
INSTALL_SERVICE_DIR="$(dirname "${MAIN_SCRIPT_PATH}")"
ROOT_DIR="$(dirname "${INSTALL_SERVICE_DIR}")"

source "${ROOT_DIR}/fct/common/terminal-tools.sh" || exit 1
source "${ROOT_DIR}/fct/common/common-tools.sh" || exit 1

script_label="lampeur"
user_name="raspi"

script_path="${ROOT_DIR}/${script_label}.sh"

lout "Ajout du groupe au script principal"
sudo chown ":${user_name}" "${script_path}"

lout "Ajout des droits de lecture et d'execution"
sudo chmod 750 "${script_path}"

lout "redémarrage du service"
source "${ROOT_DIR}/install/service_mode/${script_label}.service.sh" || eout "Impossible de trouver le script de redémarrage du service"

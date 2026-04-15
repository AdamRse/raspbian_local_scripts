#!/bin/bash
# Installer en tant que service.
# Peut être utilisé pour actualiser install/service_mode/templates/lampeur.service
# Peut être utilisé depuis un autre script (définir ROOT_DIR)

SERVICE_SCRIPT_PATH="$(readlink -f "${0}")"
INSTALL_SERVICE_DIR="$(dirname "${SERVICE_SCRIPT_PATH}")"
ROOT_DIR="${ROOT_DIR:-SERVICE_SCRIPT_PATH%/*/*/*}"

echo "DEBUG"
echo "SERVICE_SCRIPT_PATH : $SERVICE_SCRIPT_PATH"
echo "INSTALL_SERVICE_DIR : $INSTALL_SERVICE_DIR"
echo "ROOT_DIR : $ROOT_DIR"


source "${ROOT_DIR}/fct/common/terminal-tools.sh" || exit 1
source "${ROOT_DIR}/fct/common/common-tools.sh" || exit 1

# Nom du service à renseigner ici
service_name="lampeur"

# -------------------------------

service_file_name="${service_name}.service"
service_path="/etc/systemd/system/${service_file_name}"
template_service_path="${ROOT_DIR}/install/service_mode/templates/${service_file_name}"

[[ ! -f $template_service_path ]] && eout "Le template du service est introuvable dans '${template_service_path}'"

lout "Création du service ${service_file_name}"
sudo cp "${template_service_path}" "${service_path}"||eout "impossible de créer le fichier de service : '${service_path}'"
sudo chmod 644 "${service_path}"

lout "Rechargement du deamon"
sudo systemctl daemon-reload

if systemctl is-enabled --quiet ${service_file_name}; then
    lout "Redémarrage du service ${service_name}"
    sudo systemctl restart "${service_file_name}"
else
    lout "Activation du service ${service_name}"
    sudo systemctl enable "${service_file_name}"

    lout "Démarrage du service ${service_name}"
    sudo systemctl start "${service_file_name}"
fi

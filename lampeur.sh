#!/bin/bash
# Programme de gestion de cycle d'allumage et d'arrêt de lampe connectée au raspberri pi.
# Concu pour fonctionner en tant que service systemd

# -- VARIABLES --

SCRIPT_PATH=$(readlink -f "$0")
ROOT_DIR=$(dirname "$SCRIPT_PATH")

DEBUG_MODE=false
SWITCH_SCRIPT_PATH=""

run=true

source "${ROOT_DIR}/fct/common/terminal-tools.sh"
source "${ROOT_DIR}/fct/common/common-tools.sh"
source "${ROOT_DIR}/fct/lampeur.fct.sh"
[[ -f "${ROOT_DIR}/.env" ]] && source "${ROOT_DIR}/.env"

source "${ROOT_DIR}/src/opt-parser/lampeur.parser.sh"

check_requirements
set_check_globals
test_db_connect

double_switch_signal

lout "DÉMARRAGE DU PROGRAMME"
lout "--- Paramètres ---"
lout "GPIO : ${GPIO_ID}"
lout "Script de basculement : ${SWITCH_SCRIPT_PATH}"

UT_NOW=""
UT_SUNSET=""
UT_TWILIGHT=""
USER_DELAY_SEC=""
WEATHER_DELAY_SEC=""

while $run; do
    # --- CALCUL DES VALEURS ---
    tab_options=$(get_opt) || trigger_error_delay "Impossible de récupérer les options dans la table mysql, envoi du signal et attente de 1 heure."
    debug_ "tab_options:'${tab_options}'"
    read USER_DELAY_SEC run_mode <<< "${tab_options}"
    [[ $run_mode =~ ^[0-2]$ ]] ||trigger_error_delay "Impossible de récupérer les le run_mode dans la table mysql (lampe_run_skip = '${run_mode}'), envoi du signal et attente de 1 heure."
    [[ $USER_DELAY_SEC =~ ^[0-9]{1,5}$ ]] ||trigger_error_delay "Impossible de récupérer les le USER_DELAY_SEC dans la table mysql (lampe_decallage = '${USER_DELAY_SEC}'), envoi du signal et attente de 1 heure."

    today_schedule=$(get_todays_schedule) || trigger_error_delay "Impossible de récupérer les horaires dans la table mysql, envoi du signal et attente de 1 heure."
    debug_ "today_schedule:'${today_schedule}'"
    read sunset_hour_24 twilight_hour_24 <<< "${today_schedule}"

    UT_NOW=$(date +%s)
    UT_SUNSET=$(date -d $sunset_hour_24 +%s)
    UT_TWILIGHT=$(date -d $twilight_hour_24 +%s)
    if [[ ! $UT_NOW =~ ^[0-9]{10}$ ]] || [[ ! $UT_SUNSET =~ ^[0-9]{10}$ ]] || [[ ! $UT_TWILIGHT =~ ^[0-9]{10}$ ]]; then
        trigger_error_delay "Le calcul du temps unix n'a pas fonctionné : UT_NOW:${UT_NOW}, UT_SUNSET:${UT_SUNSET}, UT_TWILIGHT:${UT_TWILIGHT}. Envoi du signal et attente de 1 heure."
    fi

    WEATHER_DELAY_SEC=0
    if clouds_percent=$(get_clouds_percent_from_weather_api); then
        lout "- - Nuages aujourd'hui : ${clouds_percent}% - -"
        if ! WEATHER_DELAY_SEC=$(get_delay_from_clouds_percent ${clouds_percent}); then
            wout "La récupération du délai en fonction de la météo a échouée, elle est forcée à 0 pour la suite."
            WEATHER_DELAY_SEC=0
        fi
    fi
    lout "Décallage lié au temps actuel : ${WEATHER_DELAY_SEC}s"
    # --- DÉBUT DE LA LOGIQUE ---

    # 0 = on ne skip pas
    # 1 = On skip une fois seulement (après le skip la valeur retourne automatiquement à 0)
    # 2 = skip permanent jusqu'à changement manuel

done

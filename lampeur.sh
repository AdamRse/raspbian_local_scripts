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

while $run; do
    # --- CALCUL DES VALEURS ---
    tab_options=$(get_opt) || trigger_error_delay "Impossible de récupérer les options dans la table mysql, envoi du signal et attente de 1 heure."
    debug_ "tab_options:'${tab_options}'"
    read user_delay_sec run_mode <<< "${tab_options}"
    [[ $run_mode =~ ^[0-2]$ ]] ||trigger_error_delay "Impossible de récupérer les le run_mode dans la table mysql (lampe_run_skip = '${run_mode}'), envoi du signal et attente de 1 heure."
    [[ $user_delay_sec =~ ^[0-9]{1,5}$ ]] ||trigger_error_delay "Impossible de récupérer les le user_delay_sec dans la table mysql (lampe_decallage = '${user_delay_sec}'), envoi du signal et attente de 1 heure."

    today_schedule=$(get_todays_schedule) || trigger_error_delay "Impossible de récupérer les horaires dans la table mysql, envoi du signal et attente de 1 heure."
    debug_ "today_schedule:'${today_schedule}'"
    read sunset_hour_24 twilight_hour_24 <<< "${today_schedule}"

    ut_now=$(date +%s)
    ut_sunset=$(date -d $sunset_hour_24 +%s)
    ut_twilight=$(date -d $twilight_hour_24 +%s)
    if [[ ! $ut_now =~ ^[0-9]{10}$ ]] || [[ ! $ut_sunset =~ ^[0-9]{10}$ ]] || [[ ! $ut_twilight =~ ^[0-9]{10}$ ]]; then
        trigger_error_delay "Le calcul du temps unix n'a pas fonctionné : ut_now:${ut_now}, ut_sunset:${ut_sunset}, ut_twilight:${ut_twilight}. Envoi du signal et attente de 1 heure."
    fi

    weather_delay=0
    if clouds_percent=$(get_clouds_percent_from_weather_api); then
        lout "- - Nuages aujourd'hui : ${clouds_percent}% - -"
        if ! weather_delay=$(get_delay_from_clouds_percent ${clouds_percent}); then
            wout "La récupération du délai en fonction de la météo a échouée, elle est forcée à 0 pour la suite."
            weather_delay=0
        fi
    fi
    lout "Décallage lié au temps actuel : ${weather_delay}s"
    # --- DÉBUT DE LA LOGIQUE ---

    # 0 = on ne skip pas
    # 1 = On skip une fois seulement (après le skip la valeur retourne automatiquement à 0)
    # 2 = skip permanent jusqu'à changement manuel

done

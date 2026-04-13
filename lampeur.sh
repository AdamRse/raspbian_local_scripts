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
WAITING_TIME_SEC=""
SKIP=0

while $run; do
    echo "-----------------------------------"
    # --- CALCUL DES VALEURS ---
    tab_options=$(get_opt) || trigger_error_delay "Impossible de récupérer les options dans la table mysql, envoi du signal et attente de 1 heure."
    debug_ "tab_options:'${tab_options}'"
    read user_delay_sec run_mode <<< "${tab_options}"
    [[ $run_mode =~ ^[0-2]$ ]] ||trigger_error_delay "Impossible de récupérer les le run_mode dans la table mysql (lampe_run_skip = '${run_mode}'), envoi du signal et attente de 1 heure."
    [[ $user_delay_sec =~ ^\-?[0-9]{1,5}$ ]] ||trigger_error_delay "Impossible de récupérer les le user_delay_sec dans la table mysql (lampe_decallage = '${user_delay_sec}'), envoi du signal et attente de 1 heure."

    today_schedule=$(get_todays_schedule) || trigger_error_delay "Impossible de récupérer les horaires dans la table mysql, envoi du signal et attente de 1 heure."
    debug_ "today_schedule:'${today_schedule}'"
    read sunset_hour_24 twilight_hour_24 <<< "${today_schedule}"

    UT_NOW=$(date +%s)
    UT_SUNSET=$(date -d $sunset_hour_24 +%s)
    UT_TWILIGHT=$(date -d $twilight_hour_24 +%s)
    if [[ ! $UT_NOW =~ ^[0-9]{10}$ ]] || [[ ! $UT_SUNSET =~ ^[0-9]{10}$ ]] || [[ ! $UT_TWILIGHT =~ ^[0-9]{10}$ ]]; then
        trigger_error_delay "Le calcul du temps unix n'a pas fonctionné : UT_NOW:${UT_NOW}, UT_SUNSET:${UT_SUNSET}, UT_TWILIGHT:${UT_TWILIGHT}. Envoi du signal et attente de 1 heure."
    fi

    # !! Erreur, le weather_delay doit être calculé au moment du déclanchement, pas avant le waiting time
    weather_delay_sec=0
    if clouds_percent=$(get_clouds_percent_from_weather_api); then
        lout "- - Nuages aujourd'hui : ${clouds_percent}% - -"
        if ! weather_delay_sec=$(get_delay_from_clouds_percent ${clouds_percent}); then
            wout "La récupération du délai en fonction de la météo a échouée, elle est forcée à 0 pour la suite."
            weather_delay_sec=0
        fi
    fi

    total_delay_sec=$((weather_delay_sec + user_delay_sec))
    lout "Décallage lié au temps actuel : ${weather_delay_sec}s. décallage total : ${total_delay_sec}s"

    UT_SUNSET=$((UT_SUNSET + total_delay_sec))
    UT_TWILIGHT=$((UT_TWILIGHT + total_delay_sec))
    debug_ "Déclencheur du lever d'aujourd'hui : $(date -d @${UT_SUNSET} +'%H:%M:%S')"
    debug_ "Déclencheur du coucher d'aujourd'hui : $(date -d @${UT_TWILIGHT} +'%H:%M:%S')"


    # --- DÉBUT DE LA LOGIQUE ---

    if (( UT_NOW > UT_TWILIGHT )); then # On déclenche demain, il nous faut la date de demain matin
        UT_TOMORROW_SUNSET=$(( $(get_ut_tomorrows_sunset) + total_delay_sec ))
        WAITING_TIME_SEC=$(( UT_TOMORROW_SUNSET - UT_NOW ))
        debug_ "Déclencheur du lever de demain : $(date -d @${UT_TOMORROW_SUNSET} +'%H:%M:%S')"
        order_next_switch 0 $WAITING_TIME_SEC
    elif (( UT_NOW > UT_SUNSET )); then # On déclanche ce soir
        WAITING_TIME_SEC=$(( UT_TWILIGHT - UT_NOW ))
        debug_ "Déclencheur de ce soir : $(date -d @${UT_TOMORROW_SUNSET} +'%H:%M:%S')"
        order_next_switch 1 $WAITING_TIME_SEC
    else # On déclanche ce matin
        WAITING_TIME_SEC=$(( UT_TWILIGHT - UT_NOW ))
        debug_ "Déclencheur de ce matin : $(date -d @${UT_TOMORROW_SUNSET} +'%H:%M:%S')"
        order_next_switch 0 $WAITING_TIME_SEC
    fi

    # 0 = on ne skip pas
    # 1 = On skip une fois seulement (après le skip la valeur retourne automatiquement à 0)
    # 2 = skip permanent jusqu'à changement manuel

    # Délai tampon pour éviter les arrondis de secondes sur 24h, et le changement d'heures.
    sleep 3800
done

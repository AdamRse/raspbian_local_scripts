#!/bin/bash
# Programme de gestion de cycle d'allumage et d'arrêt de lampe connectée au raspberri pi.
# Concu pour fonctionner en tant que service systemd

# -- VARIABLES --

SCRIPT_PATH=$(readlink -f "$0")
ROOT_DIR=$(dirname "$SCRIPT_PATH")

DEBUG_MODE=false
SWITCH_SCRIPT_PATH=""

run=true

source "${ROOT_DIR}/fct/common/terminal-tools.sh" || exit 1
source "${ROOT_DIR}/fct/common/common-tools.sh" || exit 1
source "${ROOT_DIR}/fct/lampeur.fct.sh" || exit 1
[[ -f "${ROOT_DIR}/.env" ]] && source "${ROOT_DIR}/.env"

source "${ROOT_DIR}/src/opt-parser/lampeur.parser.sh" || exit 1

check_requirements
set_check_globals
is_gpio_user
test_db_connect

double_switch_signal


WAITING_TIME_SEC=""
SKIP_ON=0
SKIP_OFF=0
SUSPEND_MODE=0
MAX_WEATHER_DELAY_SEC=$(get_max_weather_delay)

lout "DÉMARRAGE DU PROGRAMME"
lout "--- Paramètres ---"
lout "GPIO : ${GPIO_ID}"
lout "Script de basculement : ${SWITCH_SCRIPT_PATH}"
lout "Délai météo maximum : ${MAX_WEATHER_DELAY_SEC}s"
debug_ "Mode debug : ON"

while $run; do
    echo "----------------- BOUCLE -----------------"

    # --- CALCUL DES VALEURS ---
    tab_options=$(get_opt) || trigger_error_delay "Impossible de récupérer les options dans la table mysql, envoi du signal et attente de 1 heure."
    read -rd '' user_delay_sec SKIP_ON SKIP_OFF SUSPEND_MODE <<< "${tab_options}"
    debug_ "-- OPTIONS --"
    debug_ "Délai utilisateur : ${user_delay_sec}s"
    debug_ "Skip à l'allumage : ${SKIP_ON}"
    debug_ "Skip à l'arrêt : ${SKIP_OFF}"
    debug_ "Suspend mode : ${SUSPEND_MODE}"

    today_schedule=$(get_todays_schedule) || trigger_error_delay "Impossible de récupérer les horaires dans la table mysql, envoi du signal et attente de 1 heure."
    read -rd '' sunset_hour_24 twilight_hour_24 <<< "${today_schedule}"
    debug_ "-- HORAIRES RÉCUPÉRÉS --"
    debug_ "Heure lever du soleil : ${sunset_hour_24}"
    debug_ "Heure coucher du soleil : ${twilight_hour_24}"

    ut_now=$(date +%s)
    ut_sunset=$(date -d $sunset_hour_24 +%s)
    ut_twilight=$(date -d $twilight_hour_24 +%s)
    if [[ ! $ut_now =~ ^[0-9]{10}$ ]] || [[ ! $ut_sunset =~ ^[0-9]{10}$ ]] || [[ ! $ut_twilight =~ ^[0-9]{10}$ ]]; then
        trigger_error_delay "Le calcul du temps unix n'a pas fonctionné : ut_now:${ut_now}, ut_sunset:${ut_sunset}, ut_twilight:${ut_twilight}. Envoi du signal et attente de 1 heure."
    fi

    ut_sunset=$((ut_sunset + user_delay_sec))
    ut_twilight=$((ut_twilight + user_delay_sec))
    debug_ "-- CALCUL DU DÉCLENCHEMENT --"
    debug_ "Déclencheur du lever d'aujourd'hui : $(date -d @${ut_sunset} +'%H:%M:%S')"
    debug_ "Déclencheur du coucher d'aujourd'hui : $(date -d @${ut_twilight} +'%H:%M:%S')"


    # --- DÉBUT DE LA LOGIQUE ---

    debug_ "-- ENVOI DE L'ORDRE --"
    if (( ut_now > ut_twilight )); then # On déclenche demain, il nous faut la date de demain matin
        UT_TOMORROW_SUNSET=$(( $(get_ut_tomorrows_sunset) + total_delay_sec ))
        WAITING_TIME_SEC=$(( UT_TOMORROW_SUNSET - ut_now ))
        debug_ "Ordre de déclenchement demain matin à $(date -d @${UT_TOMORROW_SUNSET} +'%H:%M:%S')"
        order_next_switch 0 $WAITING_TIME_SEC
    elif (( ut_now > ut_sunset )); then # On déclanche ce soir
        WAITING_TIME_SEC=$(( ut_twilight - ut_now ))
        debug_ "Ordre de déclenchement ce soir à $(date -d @${ut_twilight} +'%H:%M:%S')"
        order_next_switch 1 $WAITING_TIME_SEC
    else # On déclanche ce matin
        WAITING_TIME_SEC=$(( ut_sunset - ut_now ))
        debug_ "Ordre de déclenchement ce matin à $(date -d @${ut_sunset} +'%H:%M:%S')"
        order_next_switch 0 $WAITING_TIME_SEC
    fi

    # Délai tampon pour éviter les arrondis de secondes sur 24h.
    sleep 60
done

#!/bin/bash
# Programme de gestion de cycle d'allumage et d'arrêt de lampe connectée au raspberri pi.
# Concu pour fonctionner en tant que service systemd

# -- VARIABLES GLOBALES --

SCRIPT_PATH=$(readlink -f "$0")
ROOT_DIR=$(dirname "$SCRIPT_PATH")

VERSION=1.0
DEBUG_MODE=false
SWITCH_SCRIPT_PATH=""
WAITING_TIME_SEC=""
SKIP_ON=0
SKIP_OFF=0
SUSPEND_MODE=0
USER_DELAY_SEC=0
MAX_WEATHER_DELAY_SEC=0
SOLUNAR_CMD=""

# -- SCRIPTS --

source "${ROOT_DIR}/fct/common/terminal-tools.sh" || exit 1
source "${ROOT_DIR}/fct/common/common-tools.sh" || exit 1
source "${ROOT_DIR}/fct/lampeur.fct.sh" || exit 1
[[ -f "${ROOT_DIR}/.env" ]] && source "${ROOT_DIR}/.env"

source "${ROOT_DIR}/src/opt-parser/lampeur.parser.sh" || exit 1

# -- CKECKS --
check_requirements
is_gpio_user
test_db_connect
set_check_globals

# -- RÉSUMÉ --

lout "DÉMARRAGE DU PROGRAMME"
lout "--- Paramètres ---"
lout "Lampeur v${VERSION}"
lout "GPIO : ${GPIO_ID}"
lout "Script de basculement : ${SWITCH_SCRIPT_PATH}"
lout "Délai météo maximum : ${MAX_WEATHER_DELAY_SEC}s"
debug_ "Mode debug : ON"


# -- MAIN --
double_switch_signal
while true; do
    echo "----------------- BOUCLE -----------------"

    # --- CALCUL DES VALEURS ---
    today_schedule=$(get_todays_schedule) || trigger_error_delay "Impossible de récupérer les horaires dans la table mysql, Arrêt du programme"
    read -rd '' sunset_hour_24 twilight_hour_24 <<< "${today_schedule}"
    debug_ "-- HORAIRES RÉCUPÉRÉS --"
    debug_ "Heure lever du soleil : ${sunset_hour_24}"
    debug_ "Heure coucher du soleil : ${twilight_hour_24}"

    ut_now=$(date +%s)
    ut_sunset=$(date -d $sunset_hour_24 +%s)
    ut_twilight=$(date -d $twilight_hour_24 +%s)
    if [[ ! $ut_now =~ ^[0-9]{10}$ ]] || [[ ! $ut_sunset =~ ^[0-9]{10}$ ]] || [[ ! $ut_twilight =~ ^[0-9]{10}$ ]]; then
        trigger_error_delay "Le calcul du temps unix n'a pas fonctionné : ut_now:${ut_now}, ut_sunset:${ut_sunset}, ut_twilight:${ut_twilight}. Arrêt du programme"
    fi

    ut_sunset=$((ut_sunset + USER_DELAY_SEC))
    ut_twilight=$((ut_twilight + USER_DELAY_SEC))
    debug_ "-- CALCUL DU DÉCLENCHEMENT --"
    debug_ "Déclencheur du lever d'aujourd'hui : Le $(convert_readable_date_from_ut ${ut_sunset})"
    debug_ "Déclencheur du coucher d'aujourd'hui : Le $(convert_readable_date_from_ut ${ut_twilight})"


    # --- DÉBUT DE LA LOGIQUE ---

    debug_ "-- ENVOI DE L'ORDRE --"
    if (( ut_now > ut_twilight )); then # On déclenche demain, il nous faut la date de demain matin
        ! ut_tomorrow_sunset=$(get_ut_tomorrows_sunset) && echo "${ut_tomorrow_sunset}" && trigger_error_delay "Impossible de récupérer le timestamp du lever du soleil demain. Arrêt du programme."
        ut_tomorrow_sunset=$(( ut_tomorrow_sunset + total_delay_sec ))
        WAITING_TIME_SEC=$(( ut_tomorrow_sunset - ut_now ))
        debug_ "Ordre de déclenchement demain matin, le $(convert_readable_date_from_ut ${ut_tomorrow_sunset})"
        debug_ "Attente calculée : $ut_tomorrow_sunset - $ut_now = $WAITING_TIME_SEC"
        order_next_switch 0 $WAITING_TIME_SEC
    elif (( ut_now > ut_sunset )); then # On déclanche ce soir
        WAITING_TIME_SEC=$(( ut_twilight - ut_now ))
        debug_ "Ordre de déclenchement ce soir, le $(convert_readable_date_from_ut ${ut_twilight})"
        debug_ "Attente calculée : $ut_twilight - $ut_now = $WAITING_TIME_SEC"
        order_next_switch 1 $WAITING_TIME_SEC
    else # On déclanche ce matin
        WAITING_TIME_SEC=$(( ut_sunset - ut_now ))
        debug_ "Ordre de déclenchement ce matin, le $(convert_readable_date_from_ut ${ut_sunset})"
        debug_ "Attente calculée : $ut_sunset - $ut_now = $WAITING_TIME_SEC"
        order_next_switch 0 $WAITING_TIME_SEC
    fi


    # Délai tampon pour éviter les arrondis de secondes sur 24h.
    sleep 60
done

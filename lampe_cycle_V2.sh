#!bin/bash
# Programme de gestion de cycle d'allumage et d'arrêt de lampe connectée au raspberri pi.
# Concu pour fonctionner en tant que service systemd

# -- VARIABLES --

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
run=true
cycle=0

source "${SCRIPT_DIR}/.env"
source "${SCRIPT_DIR}/fct/terminal-tools.fct.sh"
source "${SCRIPT_DIR}/fct/lampe_cycle.fct.sh"

switch_lampe
sleep 1
switch_lampe

while $run; do
    cycle=$((cycle+1))
    dt_sql_id=$(date +%d%m)
    tab_options=$(get_opt)
    today_schedule=$(get_todays_schedule)

    sunset_hour=${today_schedule[0]}
    twilight_hour=${today_schedule[1]}
done



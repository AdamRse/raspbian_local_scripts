#!/bin/bash
# Programme de gestion de cycle d'allumage et d'arrêt de lampe connectée au raspberri pi.
# Concu pour fonctionner en tant que service systemd

# -- VARIABLES --

SCRIPT_PATH=$(readlink -f "$0")
ROOT_DIR=$(dirname "$SCRIPT_PATH")

echo "Root dir : $ROOT_DIR"

DEBUG_MODE=false
SWITCH_SCRIPT_PATH="${ROOT_DIR}/lampe_switch_pi_OS.sh"

run=true
cycle=0

source "${ROOT_DIR}/fct/common/terminal-tools.sh"
source "${ROOT_DIR}/fct/common/common-tools.sh"
source "${ROOT_DIR}/fct/lampeur.fct.sh"
[[ -f "${ROOT_DIR}/.env" ]] && source "${ROOT_DIR}/.env"

source "${ROOT_DIR}/src/opt-parser/lampeur.parser.sh"

check_requirements
set_check_globals

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

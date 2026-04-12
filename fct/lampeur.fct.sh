check_requirements(){
    if ! command -v jq &> /dev/null; then
        wout "Le paquet 'jq' n'est pas installé, et nécéssaire au programme."
        if ask_yn "Faut-il l'installer ?"; then
            sudo apt update && sudo apt install -y jq
            check_requirements
        else
            eout "Le paquet 'jq' est nécéssaire, vauillez installer jq manuellement. Arrêt du programme."
        fi
    fi
}

set_check_globals(){
    check_vars_exist "ROOT_DIR SCRIPT_PATH"
    [[ ! -f ${SWITCH_SCRIPT_PATH} ]] && SWITCH_SCRIPT_PATH="${ROOT_DIR}/lampe_switch_pi_OS.sh" && [[ ! -f ${SWITCH_SCRIPT_PATH} ]] && eout "Impossible de commuter la lampe, la variable globale SWITCH_SCRIPT_PATH n'est pas définie."
}

switch_lampe(){
    [[ ! -f ${SWITCH_SCRIPT_PATH} ]] && eout "switch_lampe() : Impossible de commuter la lampe, la variable '\$SWITCH_SCRIPT_PATH' du fichier .env n'est pas définie."
    check_vars_exist "GPIO_ID"

    bash $SWITCH_SCRIPT_PATH $GPIO_ID
}

get_opt(){
    if options=$(mysql -u "raspi" -D "raspi_general" -N -r -e "SELECT valeur FROM opt WHERE nom_opt = 'lampe_run_cycle' OR nom_opt = 'lampe_decalage'"); then
        if [ -n "${options}" ]; then
            echo $options
            return 0
        else
            wout "get_opt() : Impossible de récupérer les options"
            return 1
        fi
    else
        wout "get_opt() : La base de donnée renvoie une erreur"
        return 1
    fi
}

get_todays_schedule(){
    if schedule=$(mysql -u "raspi" -D "raspi_general" -N -r -e "SELECT lever, coucher FROM cycle_jour_nuit WHERE journee = '$(date +%d%m)'"); then
        if [ -n "${schedule}" ]; then
            echo $schedule
            return 0
        else
            wout "get_todays_schedule() : Impossible de récupérer les horraires de la journée"
            return 1
        fi
    else
        wout "get_todays_schedule() : La base de donnée renvoie une erreur"
        return 1
    fi
}

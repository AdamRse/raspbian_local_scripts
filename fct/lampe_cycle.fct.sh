switch_lampe(){
    [ -z "${SWITCH_SCRIPT_PATH}" ] && eout "switch_lampe() : Impossible de commuter la lampe, la variable '\$SWITCH_SCRIPT_PATH' du fichier .env n'est pas définie."
    [ -z "${GPIO_LIGHT}" ] && eout "switch_lampe() : Impossible de commuter la lampe, la variable '\$GPIO_LIGHT' du fichier .env n'est pas définie."

    bash $SWITCH_SCRIPT_PATH $GPIO_LIGHT
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
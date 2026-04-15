check_requirements(){ # A modifier, il faudra fa_ire un seul update upgrade à la fin
    command -v mysql &> /dev/null ||eout "La base de données mysql est nécéssaire, veuillez installer mysql/mariadb manuellement. Arrêt du programme."

    if ! command -v jq &> /dev/null; then
        wout "Le paquet 'jq' n'est pas installé, et nécéssaire au programme."
        if ask_yn "Faut-il l'installer ?"; then
            sudo apt update && sudo apt install -y jq
            check_requirements
        else
            eout "Le paquet 'jq' est nécéssaire, veuillez installer jq manuellement. Arrêt du programme."
        fi
    fi
    if ! command -v curl &> /dev/null; then
        wout "Le paquet 'curl' n'est pas installé, et nécéssaire au programme."
        if ask_yn "Faut-il l'installer ?"; then
            sudo apt update && sudo apt install -y curl
            check_requirements
        else
            eout "Le paquet 'curl' est nécéssaire, veuillez installer curl manuellement. Arrêt du programme."
        fi
    fi

}

set_check_globals(){
    check_vars_exist "ROOT_DIR SCRIPT_PATH"
    [[ ! -f ${SWITCH_SCRIPT_PATH} ]] && SWITCH_SCRIPT_PATH="${ROOT_DIR}/lampe_switch_pi_OS.sh" && [[ ! -f ${SWITCH_SCRIPT_PATH} ]] && eout "Impossible de commuter la lampe, la variable globale SWITCH_SCRIPT_PATH n'est pas définie."
}

test_db_connect(){
    local tables="cycle_jour_nuit opt"
    local connect_db

    for table in $tables; do
        connect_db="$(mysql "raspi_general" -e "DESCRIBE ${table};")"
        if [[ $? = 0 ]]; then
            debug_ "✅ La table ${table} est accessible."
        else
            debug_ "Mysql renvoie une erreur : ${connect_db}"
            eout "La base de données n'existe pas ou n'est pas accessible avec les variables du .env"
        fi
    done
    lout "Connexion aux tables mysql réussies"
}

# return exit
trigger_error_delay(){
    local message=${1}
    [[ -n $message ]] && fout "${message}"
    double_switch_signal
    exit 1
}

# $1 (optionel) : force_switch  : 1|0   : Force l'allumage (1) ou l'arrêt (0) de la lampe
# return bool
switch_lampe(){
    local force_switch=${1}

    [[ ! -f ${SWITCH_SCRIPT_PATH} ]] && eout "${FUNCNAME}() : Impossible de commuter la lampe, la variable '\$SWITCH_SCRIPT_PATH' du fichier .env n'est pas définie."
    check_vars_exist "GPIO_ID"

    bash $SWITCH_SCRIPT_PATH $GPIO_ID $force_switch
}

# Gère l'ordre de marche ou d'arrêt après un délai, gère SKIP_ON, SKIP_OFF et SUSPEND_MODE
# $1    : order_type        : 0|1   : Ordonne l'arrêt (0) ou l'allumage (1) de la lampe
# $2    : waiting_time_sec  : int   : Délai en secondes après lequel le déclenchement sera fait
# return true|exit
order_next_switch(){
    local order_type=${1}
    local waiting_time_sec=${2}
    local weather_delay_sec
    local skip_order=false
    [[ ! $SUSPEND_MODE =~ ^0|1$ ]] && wout "${FUNCNAME}() : Mauvaise calibration de SUSPEND_MODE : '${SUSPEND_MODE}'. Remise à 0 de SUSPEND_MODE." && SUSPEND_MODE=0 && mysql -D "raspi_general" -N -r -e "UPDATE opt SET valeur = '0' WHERE nom_opt = 'lampe_run_suspend'"
    [[ ! $MAX_WEATHER_DELAY_SEC =~ ^[0-9]{1,5}$ ]] && wout "${FUNCNAME}() : La variable globale MAX_WEATHER_DELAY_SEC n'est pas initialisée ou pas conforme. Désactivation de la fonction météo" && MAX_WEATHER_DELAY_SEC=0
    [[ ! $SKIP_ON =~ ^[0-9]{1,2}$ ]] && wout "${FUNCNAME}() : Variable globale SKIP_ON non initialisée. Initialisation à 0" && SKIP_ON=0
    [[ ! $SKIP_OFF =~ ^[0-9]{1,2}$ ]] && wout "${FUNCNAME}() : Variable globale SKIP_ON non initialisée. Initialisation à 0" && SKIP_OFF=0
    [[ ! $order_type =~ ^0|1$ ]] && eout "${FUNCNAME}() : Argument 1 passé (order_type='${order_type}') doit être 0 ou 1. Ordre incohérent, arrêt du script..."
    [[ ! $waiting_time_sec =~ ^[0-9]{1,5}$ ]] && eout "${FUNCNAME}() : Argument 2 passé (waiting_time_sec='${waiting_time_sec}') doit être entre 0 et 9999. Ordre incohérent, arrêt du script..."

    # Ajout de la fonction météo : si nuages, on ajoute du temps à l'arrêt (sombre plus tard), et on en enlève à l'allumage (sombre plus tôt)
    # Ici on recalcul le temps de pause avant le déclenchement e l'ordre calculé au plus tôt possible
    if [[ $order_type = 1 ]]; then
        waiting_time_sec=$(( waiting_time_sec - MAX_WEATHER_DELAY_SEC ))
    fi
    debug_ "Pause de $waiting_time_sec secondes avant d'effectuer l'ordre"
    sleep $waiting_time_sec

    # On calcule le délai à ajouter (pour éteindre) ou à enlever (pour allumer)
    if weather_delay_sec=$(get_weather_delay); then
        if [[ $order_type = 1 ]]; then # Il faut l'inverser car on a enlevé du temps. si 100% de nuage, on allume tout de suite.
            weather_delay_sec=$(( MAX_WEATHER_DELAY_SEC - weather_delay_sec ))
        fi
    else
        wout "La fonction get_weather_delay() renvoie une erreur, annulation de la fonction météo."
        if [[ $order_type = 1 ]]; then
            weather_delay_sec=$MAX_WEATHER_DELAY_SEC
        else
            weather_delay_sec=0
        fi
    fi
    debug_ "Délai du à la météo : ${weather_delay_sec}"
    sleep $weather_delay_sec

    # Vérification des skip de l'allumage et de l'arrêt
    if [[ $order_type = 1 ]]; then
        if (( SKIP_ON > 0 )); then
            debug_ "${SKIP_ON} Skip de l'allumage restant(s)"
            SKIP_ON=$(( SKIP_ON - 1 ))
            if mysql -D "raspi_general" -N -r -e "UPDATE opt SET valeur = '${SKIP_ON}' WHERE nom_opt = 'lampe_run_skip_allumage'"; then
                skip_order=true
                debug_ "Skip de l'allumage demmandé. Skip restant : ${SKIP_ON}"
            else
                fout "${FUNCNAME}() : L'enregistrement SKIP_ON (lampe_run_skip_allumage) en base de données à échoué. Aucun skip ne sera fait pour l'allumage."
                lout "Tentative de mettre à jour SKIP_ON (lampe_run_skip_allumage) à 0 dans la base de données dans 10 secondes"
                sleep 10
                ! mysql -D "raspi_general" -N -r -e "UPDATE opt SET valeur = '0' WHERE nom_opt = 'lampe_run_skip_allumage'" && fout "Tentative échoué, la requête renvoie une erreur. Envoi d'un signal lampe." && double_switch_signal
            fi
        fi
    else
        if (( SKIP_OFF > 0 )); then
            debug_ "${SKIP_OFF} Skip de l'allumage restant(s)"
            SKIP_OFF=$(( SKIP_OFF - 1 ))
            if mysql -D "raspi_general" -N -r -e "UPDATE opt SET valeur = '${SKIP_OFF}' WHERE nom_opt = 'lampe_run_skip_arret'"; then
                skip_order=true
                debug_ "Skip de l'arrêt demmandé. Skip restant : ${SKIP_OFF}"
            else
                fout "${FUNCNAME}() : L'enregistrement SKIP_OFF (lampe_run_skip_arret) en base de données à échoué. Aucun skip ne sera fait pour l'allumage."
                lout "Tentative de mettre à jour SKIP_OFF (lampe_run_skip_arret) à 0 dans la base de données dans 10 secondes"
                sleep 10
                ! mysql -D "raspi_general" -N -r -e "UPDATE opt SET valeur = '0' WHERE nom_opt = 'lampe_run_skip_arret'" && fout "Tentative échoué, la requête renvoie une erreur. Envoi d'un signal lampe." && double_switch_signal
            fi
        fi
    fi

    if [[ $skip_order = false ]]; then
        if [[ $SUSPEND_MODE = 0 ]]; then
            debug_ "Switch de la lampe à ${order_type}"
            switch_lampe $order_type
        else
            lout "Mode suspend : Switch verouillé, aucun switch à faire jusqu'à l'arrêt manuel du mode suspend."
        fi
    fi
    return 0
}

get_weather_delay(){
    local weather_delay_sec
    local clouds_percent
    ! clouds_percent=$(get_clouds_percent_from_weather_api) && echo "0" && return 0
    ! weather_delay_sec=$(get_delay_from_clouds_percent ${clouds_percent}) && echo "0" && return 0
    echo $weather_delay_sec
    return 1
}

# return "<lampe_decalage> <lampe_run_skip_allumage> <lampe_run_skip_arret> <lampe_run_suspend>"|false
get_opt(){
    local options
    ! options=$(mysql -D "raspi_general" -N -r -e "SELECT valeur FROM opt WHERE nom_opt IN ('lampe_decalage', 'lampe_run_skip_allumage', 'lampe_run_skip_arret', 'lampe_run_suspend') ORDER BY FIELD(nom_opt, 'lampe_decalage', 'lampe_run_skip_allumage', 'lampe_run_skip_arret', 'lampe_run_suspend')") && wout "${FUNCNAME}() : La base de donnée renvoie une erreur" && return 1
    [[ ! $options =~ ^[0-9]{1,5}([[:space:]][0-9]{1,2}){2}[[:space:]]0|1$ ]] && wout "${FUNCNAME}() : Les options récupérées dans la base de données ne correspondent pas aux valeurs attendues : '${options}'" && return 1
    echo "${options}"
    return 0
}

get_clouds_percent_from_weather_api(){
    local json_answer
    [[ -z $OPEN_WEATHER_API_KEY ]] && wout "Aucune clé API fournie pour open weather. Pour ajouter une clé api, ajoutez là dans OPEN_WEATHER_API_KEY dans le .env" && return 1
    ! json_answer=$(curl -s -f "https://api.openweathermap.org/data/2.5/weather?appid=${OPEN_WEATHER_API_KEY}&lat=${LATITUDE}&lon=${LONGITUDE}&units=metric&lang=fr") && fout "Échec de la requête de l'API Open Weather" && return 1

    local percent_clouds=$(jq '.clouds.all' <<< "${json_answer}")
    [[ ! $percent_clouds =~ ^[0-9]{1,3}$ ]] && fout "Échec l'extraction du pourcentage de nuages d'open weather" && return 1

    echo $percent_clouds
    return 0
}

get_delay_from_clouds_percent(){
    local percent_clouds=${1}
    [[ -z $MAX_WEATHER_DELAY_SEC ]] && MAX_WEATHER_DELAY_SEC=0 && fout "La variable globale MAX_WEATHER_DELAY_SEC n'est pas initialisée, la fonction météo est désactivée." && return 0
    [[ ! $percent_clouds =~ ^[0-9]{1,3}$ ]] && fout "La valeur donné à get_delay_from_clouds_percent() n'est pas un pourcentage" && return 1

    if [[ $percent_clouds = 100 ]]; then
        echo "${MAX_WEATHER_DELAY_SEC}" # 60 minutes
    elif (( percent_clouds > 90 )); then
        echo "1800" # 30 min
    elif (( percent_clouds > 80 )); then
        echo "1200" # 15 min
    elif (( percent_clouds > 50 )); then
        echo "900"
    elif (( percent_clouds > 30 )); then
        echo "200"
    else
        echo "0"
    fi
    return 0
}

double_switch_signal(){
    switch_lampe
    sleep 1
    switch_lampe
    sleep 1
}

get_todays_schedule(){
    local schedule
    ! schedule=$(mysql -D "raspi_general" -N -r -e "SELECT lever, coucher FROM cycle_jour_nuit WHERE journee = '$(date +%d%m)'") && wout "${FUNCNAME}() : La base de donnée renvoie une erreur" && return 1
    [[ ! $schedule =~ ^([0-9][0-9]:){2}[0-9][0-9][[:space:]]([0-9][0-9]:){2}[0-9][0-9]$ ]] && wout "${FUNCNAME}() : La base de donnée ne retourne pas d'horaires au bon format : '${schedule}'" && return 1
    echo "${schedule}"
    return 0
}

get_ut_tomorrows_sunset(){
    local ut_tomorrow=$(($(date +%s) + 86400))
    ! schedule=$(mysql -D "raspi_general" -N -r -e "SELECT lever FROM cycle_jour_nuit WHERE journee = '$(date -d @${ut_tomorrow} +%d%m)'") && fout "Impossible de récupérer la date du lever du lendemain" && return 1
    [[ ! $schedule =~ ^([0-9][0-9]:){2}([0-9][0-9])$ ]] && fout "La date récupérée pour le lever du lendemain n'est pas au bon format. Date récupérée : '${schedule}'" && return 1
    echo $(date -d ${schedule} +%s)
    return 0
}

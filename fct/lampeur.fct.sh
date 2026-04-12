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
        connect_db="$(mysql -u "raspi" "raspi_general" -e "DESCRIBE ${table};")"
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

    [[ ! -f ${SWITCH_SCRIPT_PATH} ]] && eout "switch_lampe() : Impossible de commuter la lampe, la variable '\$SWITCH_SCRIPT_PATH' du fichier .env n'est pas définie."
    check_vars_exist "GPIO_ID"

    bash $SWITCH_SCRIPT_PATH $GPIO_ID $force_switch
}

# return "<mode de cycle 0, 1, 2> <décallage ensecodnes>"|false
get_opt(){
    if options=$(mysql -u "raspi" -D "raspi_general" -N -r -e "SELECT valeur FROM opt WHERE nom_opt = 'lampe_run_skip' OR nom_opt = 'lampe_decalage'"); then
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
    [[ ! $percent_clouds =~ ^[0-9]{1,3}$ ]] && fout "La valeur donné à get_delay_from_clouds_percent() n'est pas un pourcentage" && return 1

    if [[ $percent_clouds = 100 ]]; then
        echo "3600" # 60 minutes
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

# Détermine selon l'heure, si la lampe doit s'allumer ou s'éteindre
auto_switch(){
    return 0
}

double_switch_signal(){
    switch_lampe
    sleep 1
    switch_lampe
    sleep 1
}

get_todays_schedule(){
    if schedule=$(mysql -u "raspi" -D "raspi_general" -N -r -e "SELECT lever, coucher FROM cycle_jour_nuit WHERE journee = '$(date +%d%m)'"); then
        if [ -n "${schedule}" ]; then
            echo $schedule
            return 0
        else
            wout "get_todays_schedule() : Impossible de récupérer les horaires de la journée"
            return 1
        fi
    else
        wout "get_todays_schedule() : La base de donnée renvoie une erreur"
        return 1
    fi
}

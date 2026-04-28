# Vérifie si les paquets nécéssaires ou conseillés sont installés
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
    if ! command -v solunar &> /dev/null && ! command -v "${ROOT_DIR}/bin/solunar2-aarch64" &> /dev/null; then
        wout "Solunar 2 n'est pas installé, c'est un programme optionel qui sera utilisé pour déterminer les horaires de lever et coucher du soleil localement. Installez-le et rendez-le executable pour ${USER} si vous voulez utiliser solunar 2."
        ask_yn "La base de données sera utilisée par défaut (moins précise) Continuer sans solunar 2 ?" || lout "Arrêt du programme par l'utilisateur." && exit 0
    fi
}

# Vérifie et paramètre les variables globales
# return true|exit
set_check_globals(){
    check_vars_exist "ROOT_DIR SCRIPT_PATH"
    [[ ! -f ${SWITCH_SCRIPT_PATH} ]] && SWITCH_SCRIPT_PATH="${ROOT_DIR}/lampe_switch_pi_OS.sh" && [[ ! -f ${SWITCH_SCRIPT_PATH} ]] && eout "Impossible de commuter la lampe, la variable globale SWITCH_SCRIPT_PATH n'est pas définie."

    [[ -z $GPIO_ID ]] && eout "Variable GPIO_ID obligatoire dans le .env. Ajouter l'identifiant du GPIO à commander pour contrôler pour la lampe."
    [[ ! $GPIO_ID =~ ^[0-9]+$ ]] && eout "La variable GPIO_ID du .env doit être un nombre. En cas de mise à jour de la convention de nommage des GPIO, modifiez cette ligne dans ${FUNCNAME}(), cette vérification est devenue obsolète."

    # METEO
    if [[ -n $PARAM_WEATHER_DELAY ]]; then
        for entry in "${PARAM_WEATHER_DELAY[@]}"; do
            IFS=":" read -r percent delay <<< "${entry}"
            [[ -z $percent || -z $delay ]] && eout "Fichier .env : PARAM_WEATHER_DELAY mal structuré. Doit être de la forme PARAM_WEATHER_DELAY=('<pourcentage nuages>:<délai ajouté en secondes>' '100:3600' '50:900'...)"
            [[ ! $percent =~ ^[0-9]{1,3}$ ]] && eout "Fichier .env : PARAM_WEATHER_DELAY mal structuré. Le chiffre avant le séparateur ':' doit être un nombre entier (pourcentage de couverture nuageuse)"
            (( percent < 0 || percent > 100 )) && eout "Fichier .env : PARAM_WEATHER_DELAY mal structuré. Le chiffre avant le séparateur ':' doit être un nombre entier entre 0-100"
            [[ ! $delay =~ ^[0-9]{1,4}$ ]] && eout "Fichier .env : PARAM_WEATHER_DELAY mal structuré. Le chiffre après le séparateur ':' doit être un nombre entier entre 0 et 9999 (secondes de délai en foonction de la couverture nuageuse)"
        done
    fi

    MAX_WEATHER_DELAY_SEC=$(get_max_weather_delay)

    if [[ -n $LATITUDE && -n $LONGITUDE ]]; then
        [[ ! $LATITUDE =~ ^-?[0-9]{1,2}\.[0-9]{1,6}$ ]] && eout "La LATITUDE donnée dans le .env n'est pas une latitude (entre -90.0 et +90.0). S'il n'y a pas de décimales, entrez xx.0"
        ! awk -v lat="$LATITUDE" 'BEGIN {exit !(lat >= -90 && lat <= 90)}' && eout "La LATITUDE donnée dans le .env n'est pas une latitude (entre -90.0 et +90.0)"
        [[ ! $LONGITUDE =~ ^-?[0-9]{1,3}\.[0-9]{1,6}$ ]] && eout "La LONGITUDE donnée dans le .env n'est pas une latitude (entre -180.0 et +180.0). S'il n'y a pas de décimales, entrez xx.0"
        ! awk -v lon="$LONGITUDE" 'BEGIN {exit !(lon >= -180 && lon <= 180)}' && eout "La LONGITUDE donnée dans le .env n'est pas une latitude (entre -180.0 et +180.0)"
    else
        wout "Coordonnées météo manquantes (LATITUDE, LONGITUDE) dans le .env, désactivation de la fonction météo"
        MAX_WEATHER_DELAY_SEC=0
    fi

    if [[ -z $OPEN_WEATHER_API_KEY ]]; then
        wout "Clé API Open Weather manquante (OPEN_WEATHER_API_KEY) dans le .env, désactivation de la fonction météo"
        MAX_WEATHER_DELAY_SEC=0
    fi

    # SOLUNAR
    local solunar_cmd="solunar"
    if command -v "${solunar_cmd}" &> /dev/null; then
        SOLUNAR_CMD="${solunar_cmd}"
    else
        solunar_cmd="${ROOT_DIR}/bin/solunar2-aarch64"
        if command -v "${solunar_cmd}" &> /dev/null; then
            SOLUNAR_CMD="${solunar_cmd}"
        else
            fout "Solunar inaccessible pour ${USER}. Il est conseillé d'utiliser solunar pour calculer localement l'heure de lever et de coucher du soleil."
            lout "Sur une architecture arm64, vous pouvez simplement rendre ${solunar_cmd} executable par ${USER}. Si non compatible, installez https://github.com/kevinboone/solunar2"
        fi
    fi
    command -v "${solunar_cmd}" &> /dev/null && lout "Solunar utilisera la timezone locale"

    # END
    lout "✅ Variables globales cohérentes"
    refresh_opt
}

# Teste si l'utilisateur a les droits pour contrôler le gpio
# return true|exit
is_gpio_user(){
    if groups "$USER" | grep -q "\bgpio\b" || [[ $EUID -eq 0 ]]; then
        lout "✅ L'utilisateur a bien accès au groupe gpio"
        return 0
    else
        eout "L'utilisateur n'a pas accès au groupe 'gpio' et ne peut donc commander le basculement. Arrêt du programme."
    fi
}

# Test l'accès à plusieurs tables dans la base de données
# return true|exit
test_db_connect(){
    local tables="cycle_jour_nuit opt"
    local connect_db

    for table in $tables; do
        connect_db="$(mysql "raspi_general" -e "DESCRIBE ${table};")"
        if [[ $? = 0 ]]; then
            debug_ "✅ La table ${table} est accessible."
        else
            debug_ "Mysql renvoie une erreur : ${connect_db}"
            eout "La base de données n'existe pas ou n'est pas accessible en socket unix par l'utilisateur ${USER}"
        fi
    done
    lout "✅ Connexion aux tables mysql réussies"
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

    bash $SWITCH_SCRIPT_PATH $GPIO_ID $force_switch ||eout "Impossible de switcher le GPIO ${GPIO_ID}, vérifiez le droits de l'utilisateur du script, il doit accéder au groupe 'gpio'"
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
    [[ ! $MAX_WEATHER_DELAY_SEC =~ ^[0-9]{1,5}$ ]] && wout "${FUNCNAME}() : La variable globale MAX_WEATHER_DELAY_SEC n'est pas initialisée ou pas conforme. Désactivation de la fonction météo" && MAX_WEATHER_DELAY_SEC=0
    [[ ! $SKIP_ON =~ ^[0-9]{1,2}$ ]] && wout "${FUNCNAME}() : Variable globale SKIP_ON non initialisée. Initialisation à 0" && SKIP_ON=0
    [[ ! $SKIP_OFF =~ ^[0-9]{1,2}$ ]] && wout "${FUNCNAME}() : Variable globale SKIP_ON non initialisée. Initialisation à 0" && SKIP_OFF=0
    [[ ! $order_type =~ ^0|1$ ]] && eout "${FUNCNAME}() : Argument 1 passé (order_type='${order_type}') doit être 0 ou 1. Ordre incohérent, arrêt du script..."
    [[ ! $waiting_time_sec =~ ^[0-9]{1,5}$ ]] && eout "${FUNCNAME}() : Argument 2 passé (waiting_time_sec='${waiting_time_sec}') doit être entre 0 et 9999. Ordre incohérent, arrêt du script..."

    # Ajout de la fonction météo : si nuages, on ajoute du temps à l'arrêt (sombre plus tard), et on en enlève à l'allumage (sombre plus tôt)
    # Ici on recalcul le temps de pause avant le déclenchement e l'ordre calculé au plus tôt possible
    if [[ $order_type = 1 ]]; then
        local waiting_time_sec_calculated_negative=0 # Pour le cas où on attend un temps négatif (on envoi la demande avant le temps d'attente max de MAX_WEATHER_DELAY_SEC), on doit répercuter le temps enlevé par la remise à 0 dans le calcul suivant
        waiting_time_sec=$(( waiting_time_sec - MAX_WEATHER_DELAY_SEC ))
        debug_ "Calcul du temps d'attente vis à vis de la météo pour l'allumage, renversement pour un délai max de ${MAX_WEATHER_DELAY_SEC} : ${waiting_time_sec}s"
        if ((waiting_time_sec < 0 )); then
            waiting_time_sec_calculated_negative=$waiting_time_sec
            waiting_time_sec=0
            debug_ "Remise à 0 pour cause de temps négatif"
        fi
    fi
    debug_ "Pause de $waiting_time_sec secondes avant d'effectuer l'ordre"
    sleep $waiting_time_sec

    if (( MAX_WEATHER_DELAY_SEC > 0 )); then
        # On calcule le délai à ajouter (pour éteindre) ou à enlever (pour allumer)
        if weather_delay_sec=$(get_weather_delay); then
            if [[ $order_type = 1 ]]; then # Il faut l'inverser car on a enlevé du temps précédement. si 100% de nuage, on allume tout de suite.
                weather_delay_sec=$(( MAX_WEATHER_DELAY_SEC + waiting_time_sec_calculated_negative - weather_delay_sec ))
                debug_ "Re-calcul du temps d'attente vis à vis de la météo pour l'allumage, compensation du renversement pour un délai max de ${MAX_WEATHER_DELAY_SEC} : ${weather_delay_sec}s"
                (( weather_delay_sec < 0 )) && weather_delay_sec=0 && debug_ "weather_delay_sec < 0, recalibration à 0"
            fi
        else
            wout "La fonction get_weather_delay() renvoie une erreur, annulation de la fonction météo."
            if [[ $order_type = 1 ]]; then
                weather_delay_sec=$MAX_WEATHER_DELAY_SEC
            else
                weather_delay_sec=0
            fi
        fi
        debug_ "Délai dû à la météo : ${weather_delay_sec}s"
        sleep $weather_delay_sec
    else
        wout "Fonction météo ignorée. Ajoutez une variable MAX_WEATHER_DELAY_SEC conforme dans le .env et relancez le service pour l'activer."
    fi
    refresh_opt

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
            debug_ ":: Switch de la lampe à ${order_type} ::"
            switch_lampe $order_type
        else
            lout ":: Mode suspend : Switch verouillé, aucun switch à faire jusqu'à l'arrêt manuel du mode suspend ::"
        fi
    fi

    # On réapplique le délai enlevé par la fonction météo, sinon on va refaire le calcul pour la même journée. On cas de SKIP_ON, il seront tous décrémentés jusqu'à 0.
    [[ $order_type = 1 ]] && sleep $(( MAX_WEATHER_DELAY_SEC - weather_delay_sec + 1 ))
    return 0
}

get_weather_delay(){
    local weather_delay_sec
    local clouds_percent
    ! clouds_percent=$(get_clouds_percent_from_weather_api) && echo "${clouds_percent}" && return 1
    ! weather_delay_sec=$(get_delay_from_clouds_percent ${clouds_percent}) && echo "${weather_delay_sec}" && return 1
    echo $weather_delay_sec
}

# Retourn un délai d'attente en fonction du % de couverture nuageuse, à partie de PARAM_WEATHER_DELAY dans le .env
# $1    : cloud_percent : 0-100 : Pourcentage de couverture nuageuse
# return int
get_delay_from_clouds_percent() {
    local cloud_percent=$1
    local found_delay=0
    [[ $MAX_WEATHER_DELAY_SEC = 0 ]] && echo "0" && return 0
    [[ ! $cloud_percent =~ ^[0-9]{1,3}$ ]] && wout "${FUNCNAME}() : Le paramètre passé cloud_percent (${cloud_percent}) n'est pas un pourcentage. La fonction météo sera désactivée." && return 1

    for entry in "${PARAM_WEATHER_DELAY[@]}"; do
        IFS=":" read -r percent delay <<< "${entry}"

        if (( cloud_percent >= percent )); then
            (( percent > found_delay )) && found_delay=$delay
        fi
    done
    echo "${found_delay}"
}

# Renvoie un pourcentage de couverture nuageuse en fonction des coordonnées entrées dans le .env
# return "<int 1-100>"| false
get_clouds_percent_from_weather_api(){
    local json_answer
    [[ -z $OPEN_WEATHER_API_KEY ]] && wout "Aucune clé API fournie pour open weather. Pour ajouter une clé api, ajoutez là dans OPEN_WEATHER_API_KEY dans le .env" && return 1
    ! json_answer=$(curl -s -f "https://api.openweathermap.org/data/2.5/weather?appid=${OPEN_WEATHER_API_KEY}&lat=${LATITUDE}&lon=${LONGITUDE}&units=metric&lang=fr") && fout "Échec de la requête de l'API Open Weather" && return 1

    local percent_clouds=$(jq '.clouds.all' <<< "${json_answer}")
    [[ ! $percent_clouds =~ ^[0-9]{1,3}$ ]] && fout "Échec l'extraction du pourcentage de nuages d'open weather" && return 1

    echo $percent_clouds
    return 0
}

# Donne le délai max en secondes de PARAM_WEATHER_DELAY dans le .env
# return "0-100"
get_max_weather_delay(){
    local max_delay=0

    for entry in "${PARAM_WEATHER_DELAY[@]}"; do
        IFS=":" read -r percent delay <<< "${entry}"
        if (( delay > max_delay )); then
            max_delay=$delay
        fi
    done
    echo "${max_delay}"
}

# Lis les options en base de données et refresh les variables globales
refresh_opt(){
    local options
    ! options=$(mysql -D "raspi_general" -N -r -e "SELECT valeur FROM opt WHERE nom_opt IN ('lampe_decalage', 'lampe_run_skip_allumage', 'lampe_run_skip_arret', 'lampe_run_suspend') ORDER BY FIELD(nom_opt, 'lampe_decalage', 'lampe_run_skip_allumage', 'lampe_run_skip_arret', 'lampe_run_suspend')") && wout "${FUNCNAME}() : La base de donnée renvoie une erreur" && return 1
    [[ ! $options =~ ^-?[0-9]{1,5}([[:space:]][0-9]{1,2}){2}[[:space:]]0|1$ ]] && wout "${FUNCNAME}() : Les options récupérées dans la base de données ne correspondent pas aux valeurs attendues : '${options}'" && return 1
    read -rd '' USER_DELAY_SEC SKIP_ON SKIP_OFF SUSPEND_MODE <<< "${options}"
    debug_ "-- REFRESH OPTIONS --"
    debug_ "Délai utilisateur : ${USER_DELAY_SEC}s"
    debug_ "Skip à l'allumage : ${SKIP_ON}"
    debug_ "Skip à l'arrêt : ${SKIP_OFF}"
    debug_ "Suspend mode : ${SUSPEND_MODE}"
}

double_switch_signal(){
    switch_lampe
    sleep 1
    switch_lampe
    sleep 1
    return 0
}

# Retourne la date de lever et de coucher du soleil pour la journée donnée en temps UNIX, en utilisant solunar (par defaut : aujourd'hui)
# $1 (optionel) : date_ut_request : unix timestamp  : Date à laquelle renvoyer l'heure de lever et de coucher du soleil. Par défaut : now
# return "<heure lever HH:MM:SS> <heure coucher HH:MM:SS>"|false
get_schedule_from_ut_solunar(){
    local date_ut_request=${1:-$(date +"%s")}
    local ans_solunar=""
    local sunrise
    local sunset
    [[ ! $date_ut_request =~ ^[0-9]{10}$ ]] && fout "${FUNCTION}() : la date passée doit être au format timestamp UNIX (10 chiffres). Argument reçu : ${date_ut_request}." && return 1
    local date_request=$(date -d "@${date_ut_request}" "+%Y-%m-%d")
    [[ ! $date_request =~ ^2[0-9]{3}\-(0|1)[0-9]\-[0-3][0-9]$ ]] && fout "${FUNCTION}() : la date passée doit être post 2000 et au format YYYY-MM-DD. Argument reçu : ${date_request}." && return 1
    ! command -v $SOLUNAR_CMD &> /dev/null && debug_ "${FUNCTION}() : Commande '${SOLUNAR_CMD}' impossibele à executer pour ${USER}" && return 1

    ! ans_solunar="$($SOLUNAR_CMD -d $date_request -l $LATITUDE -o $LONGITUDE 2>/dev/null)" && debug_ "${FUNCTION}() : La commande '${SOLUNAR_CMD}' a échouée. Retour : ${ans_solunar}" && return 1

    sunrise=$(echo "${ans_solunar}" | grep "Sunrise" | awk '{print $2}')
    sunset=$(echo "${ans_solunar}" | grep "Sunset" | awk '{print $2}')

    [[ ! $sunrise =~ ^[0-9]{2}\:[0-9]{2}$ ]] && debug_ "${FUNCTION}() : La récupération de sunrise a échoué. La commande '${SOLUNAR_CMD}' retourne : ${ans_solunar}" && return 1
    [[ ! $sunset =~ ^[0-9]{2}\:[0-9]{2}$ ]] && debug_ "${FUNCTION}() : La récupération de sunrise a sunset. La commande '${SOLUNAR_CMD}' retourne : ${ans_solunar}" && return 1

    echo "${sunrise}:00 ${sunset}:00"
}

# Retourne la date de lever et de coucher du soleil pour la journée donnée en temps UNIX, en utilisant la base de données installée (par defaut : aujourd'hui)
# $1 (optionel) : date_ut_request : unix timestamp  : Date à laquelle renvoyer l'heure de lever et de coucher du soleil. Par défaut : now
# return "<heure lever HH:MM:SS> <heure coucher HH:MM:SS>"|false
get_schedule_from_ut_db(){
    local date_ut_request=${1:-$(date +"%s")}
    [[ ! $date_ut_request =~ ^[0-9]{10}$ ]] && fout "${FUNCTION}() : La date passée doit être au format timestamp UNIX (10 chiffres). Argument reçu : ${date_ut_request}." && return 1
    local date_request=$(date -d "@${date_ut_request}" "+%d%m")
    [[ ! $date_request =~ ^[0-3][0-9](0|1)[0-9]$ ]] && fout "${FUNCTION}() : L'ID de la table 'cycle_jour_nuit' n'est pas reconnu : '${date_request}'" && return 1

    ! schedule="$(mysql -D "raspi_general" -N -r -e "SELECT lever, coucher FROM cycle_jour_nuit WHERE journee = '${date_request}'"| tr '\t' ' ')" && wout "${FUNCNAME}() : La base de donnée renvoie une erreur" && return 1
    [[ ! $schedule =~ ^([0-9][0-9]:){2}[0-9][0-9][[:space:]]([0-9][0-9]:){2}[0-9][0-9]$ ]] && wout "${FUNCNAME}() : La base de donnée ne retourne pas d'horaires au bon format : '${schedule}'" && return 1
    echo "$schedule"
}
get_todays_schedule(){
    local schedule

    schedule=$(get_schedule_from_ut_solunar) && echo "${schedule}" && return 0
    schedule=$(get_schedule_from_ut_db) && echo "${schedule}" && return 0

    fout "${FUNCNAME}() : Impossible de trouver les horaires avec les moyens disponibles."
    return 1
}
get_ut_tomorrows_sunset(){
    local schedule
    local ut_date
    local tomorrow_ut=$(date -d "tomorrow" "+%s")

    [[ -n $SOLUNAR_CMD ]] && schedule=$(get_schedule_from_ut_solunar ${tomorrow_ut})
    [[ -z $schedule ]] && schedule=$(get_schedule_from_ut_db ${tomorrow_ut})
    [[ ! $schedule =~ ^([0-2][0-9]\:[0-5][0-9]\:[0-5][0-9][[:space:]]?){2}$ ]] && fout "${FUNCNAME}() : Impossible de trouver les horaires avec les moyens disponibles." && return 1

    ! ut_date=$(date -d "tomorrow ${schedule%% *}" "+%s") && fout "${FUNCNAME}() : Impossible de convertir la date retournée : '${schedule}' > '${schedule%% *}'." && return 1

    echo $ut_date
}

convert_readable_date_from_ut(){
    local given_date=${1}
    local calculated_date
    [[ ! $given_date =~ [0-9]{1,10} ]] && wout "${FUNCNAME}() : La date donnée n'est pas un timestamp unix" && return 1
    ! calculated_date="$(date -d @${given_date} +'%a %d %b à %H:%M:%S')"  && wout "${FUNCNAME}() : La date donnée n'est pas convertible" && return 1
    echo "${calculated_date}"
}

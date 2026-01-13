# -- VARIABLES --

# Styles pour les logs
S_ERROR=$(tput setaf 9)         # Rouge vif
#S_ERROR='\e[38;5;9m'           # Rouge vif
S_SUCCESS=$(tput setaf 118)     # Vert
#S_SUCCESS='\e[38;5;118m'       # Vert
S_WARNING=$(tput setaf 220)     # Jaune
#S_WARNING='\e[38;5;220m'       # Jaune
S_INFO=$(tput setaf 75)         # Bleu fixe
#S_INFO='\e[38;5;75m'           # Bleu fixe
S_PARAM=$(tput setaf 219)       # Cyan clair
#S_PARAM='\e[38;5;219m'         # Cyan clair
S_PROCESS=$(tput setaf 229)     # Jaune clair
#S_PROCESS='\e[38;5;229m'       # Jaune clair
S_BOLD=$(tput bold)             # Gras
S_END=$(tput sgr0)              # Balise de fin de styles
#S_END='\033[0m'                # Balise de fin de styles

# -- LOGS --

# Log standard
lout(){
    local message=$1
    [ -z "$message" ] && echo "lout() : Aucun paramètre passé pour message" >&2
    echo -e "${S_INFO}[INFO]${S_END} $message"
}

# Success
sout(){
    local message=$1
    [ -z "$message" ] && echo "sout() : Aucun paramètre passé pour message" >&2
    echo -e "${S_SUCCESS}[SUCCESS]${S_END} $message ${S_SUCCESS}✓${S_END}"
}

# Warning, le script continue
wout(){
    local message=$1
    [ -z "$message" ] && echo "wout() : Aucun paramètre passé pour message" >&2
    echo -e "${S_WARNING}[WARNING]${S_END} $message" >&2
}

# Fail, erreur mais le script continue
fout(){
    local message=$1
    [ -z "$message" ] && echo "fout() : Aucun paramètre passé pour message" >&2
    echo -e "${S_ERROR}[FAIL]${S_END} $message" >&2
}

# Erreur, arrête le script
eout(){
    local message=$1
    [ -z "$message" ] && echo "eout() : Aucun paramètre passé pour message" >&2
    echo -e "${S_ERROR}[ERROR]${S_END} $message" >&2
    exit 1
}

# Uniquement affiché en mode debug
debug_(){
    if $debug_mode; then
        local message=$1
        [ -z "$message" ] && echo "debug_() : Aucun paramètre passé pour message" >&2
        echo -e "[DEBUG] $message"
    fi
}

# -- FONCTIONNALITÉS --

# Question fermée attend une réponse, et renvoie true|false en fonction de la réponse
ask_yn () {
    if [ -z "$1" ]; then
        echo -e "fonction ask_yn() : Aucun paramètre passé" >&2
        exit 1
    fi

    while true; do
        echo -ne "${S_PARAM}[PARAM]${S_END} $1 (o/n)"
        read -n 1 -p "" response
        echo ""
        # Vérification de la réponse
        if [[ $response == "o" || $response == "O" ]]; then
            return 0
        elif [[ $response == "n" || $response == "N" ]]; then
            return 1
        else
            wout "'$response' : Réponse invalide. Veuillez entrer 'o' (Oui) ou 'n' (Non)."
        fi
    done
}

# $1 : PID du processus à surveiller
# [$2] : Message à afficher pendant l'attente
# return string|false
show_spinner() {
    if ! kill -0 $1 2>/dev/null; then
        wout "Show_spinner() : aucun PID passé, le spinner ne fonctionnera pas"
        return 1
    fi
    if [ -z "${2}" ]; then
        local message="${S_PROCESS}[PROCESS]${S_END} Processus en cours ..."
    else
        local message="${S_PROCESS}[PROCESS]${S_END} $2"
    fi

    local pid=$1
    local spin='-\|/'
    local i=0
    
    echo -n "${message} " >&2
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r${message} ${S_PROCESS}${spin:$i:1}${S_END}" >&2
        sleep 0.1
    done
    printf "\r${message} ${S_PROCESS}✓${S_END}\n" >&2
}
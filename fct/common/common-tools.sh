# > REQUIERT terminal-tools.sh
#
# Vérifie si les variables données sont globales
# $1    : var_list  : "var1 var2"   : tableau de variables, chaîne avec un séparateur espace
# return empty|exit
check_vars_exist(){
    local var_list=${1}
    [[ -z $var_list ]] && eout "${FUNCNAME[0]}() : Aucun paramètre donné via ${FUNCNAME[1]}()"
    local fct_name="${FUNCNAME[1]}() : "

    for var_name in $var_list; do
        if [[ -z "${!var_name}" ]]; then
            if [[ $DEBUG_MODE = true ]]; then
                local all_functions_name
                for fct_all_name in "${FUNCNAME[@]}"; do
                    [[ $fct_all_name = ${FUNCNAME[0]} ]] && continue
                    if [[ -n $all_functions_name ]]; then
                        all_functions_name="${fct_all_name}() -> ${all_functions_name}"
                    else
                        all_functions_name="${fct_all_name}()"
                    fi
                done
                debug_ "${all_functions_name} : '$var_name' n'est pas initialisée"
            fi
            eout "${fct_name}La variable '$var_name' n'est pas initialisée, arrêt du script"
        fi
    done
}

# Check si une liste de fonctions est disponible
# $1    : fct_list  : "fct1 fct2"   : tableau de variables, chaîne avec un séparateur espace
# return empty|exit
check_functions_exist(){
    local fct_list=${1}
    [[ -z $fct_list ]] && eout "${FUNCNAME[0]}() : Aucun paramètre passé depuis ${FUNCNAME[1]}()"

    for fct_name in $fct_list; do
        if ! declare -f $fct_name > /dev/null; then
            if [[ $DEBUG_MODE = true ]]; then
                local all_functions_name
                for fct_all_name in "${FUNCNAME[@]}"; do
                    [[ $fct_all_name = ${FUNCNAME[0]} ]] && continue
                    if [[ -n $all_functions_name ]]; then
                        all_functions_name="${fct_all_name}() -> ${all_functions_name}"
                    else
                        all_functions_name="${fct_all_name}()"
                    fi
                done
                debug_ "${all_functions_name} : '$fct_name' n'est pas initialisée"
            fi
            eout "${fct_name}La fonction '$fct_name' n'est pas initialisée, arrêt du script"
        fi
    done
}

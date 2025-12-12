#!/bin/bash

#NOTE PUSH 2

pid=$$
#change

function get_cpu_temp()
{   
  line=$(head -n 1 /sys/class/thermal/thermal_zone0/temp)
  echo $(awk "BEGIN {printf \"%.2f\n\", $line/1000}")
}

function obtenir_opt()
{
  echo $(mysql -u "raspi" -D "raspi_general" -s -N  -e "SELECT valeur FROM opt WHERE nom_opt = 'temperature_frequence_check' OR nom_opt = 'temperature_warning_alert_trigger_limit' OR nom_opt = 'temperature_warning_alert_trigger';")
}

function alerter()
{
  wget -q --spider  "https://smsapi.free-mobile.fr/sendmsg?user=22683416&pass=LslzRq4Tz04fDE&msg=Alerte sur le raspi : $1"
}

#pour éviter de donner la même alerte à chaque cycle de test
alerteDonnee="0"
run=true

mysql -u "raspi" -D "raspi_general" -s -N  -e "UPDATE opt SET valeur = '$pid' WHERE nom_opt = 'temperature_run'"

while $run; do
  #initialisation des variables pour le controle
  horloge=120
  temp_limite=60

  #réccupérer la température du raspi
  temperature=$(get_cpu_temp)

  #réccupérer les options en bdd
  opts=$(obtenir_opt)

  #mettre les options récupérées (dans une string séparée par des espaces) dans un tableau (on ADDR.split(" "))
  #IFS=' '
  read -ra tabOpt <<< "$opts"
  #pour tester la string reçue de la bdd:
  #echo "$opts"
  tempLimiteBasse=$(( ${tabOpt[2]} - 4 ))

  #pas d'alerte à donner si la surchaufe a déjà été signalée
  if [ $alerteDonnee == "0" ]
  then
    #on teste le booléen de la bdd, colonne temperature_warning_alert_trigger, pour voir si on fait le test
    if [ ${tabOpt[1]} == "1" ]
    then
      #check de l'alerte température passée en bdd par la colonne temperature_warning_alert_trigger_limit
      #-ge : supérieur ou égal
      if (( $(echo "$temperature > ${tabOpt[2]}" |bc -l) ));
      then
        alerter "Surchauffe du processeur à $temperature degrés (seuil d'alerte à ${tabOpt[2]} degrés)"
        alerteDonnee="1"
      fi
    fi
  else
    #-lt : strictement inferieur à
    if (( $(echo "$temperature < $tempLimiteBasse" |bc -l) ));
    then
      #fin de l'alerte, les tests de température pour signaler une nouvelle alerte peuvent reprendre
      alerteDonnee="0"
    fi
  fi

  #on teste l'ordre de fréquence des tests données par la bdd, colonne temperature_frequence_check
  if [ ${tabOpt[0]} != "" ] && (( ${tabOpt[0]} > 0  ))
  then
    horloge=${tabOpt[0]}
  fi

  if [ $(mysql -u "raspi" -D "raspi_general" -s -N  -e "SELECT valeur FROM opt WHERE nom_opt = 'temperature_run'") != $pid ]
  then
    run=false
  fi

  $(mysql -u "raspi" -D "raspi_general" -e "INSERT INTO temp_log (temperature) VALUES ($temperature);")
  echo -e "température\t$temperature"
  echo -e "horloge\t\t$horloge"

  sleep $horloge
done

mysql -u "raspi" -D "raspi_general" -s -N  -e "UPDATE opt SET valeur = '0' WHERE nom_opt = 'temperature_run'"

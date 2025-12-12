#!bin/bash
pid=$$
horloge=5
run=true
t_alert=false;
mysql -u "raspi" -D "raspi_general" -s -N  -e "UPDATE opt SET valeur = '$pid' WHERE nom_opt = 'monitoring_run'"
echo "Lancement du script de monitoring"

while $run;
do
  #récupération des options et commandes dans la bdd
  read -ra tabOpt -d $'\0' <<< $(mysql -u "raspi" -D "raspi_general" -s -N  -e "SELECT valeur FROM opt WHERE nom_opt = 'temperature_warning_alert_trigger_limit' OR nom_opt = 'temperature_warning_alert_trigger' OR nom_opt = 'monitoring_ram_alert_limit' OR nom_opt = 'monitoring_ram_alert'")
  echo "donnerAlerte TEMP ${tabOpt[2]} / temp limite pour donner l'alerte ${tabOpt[3]} / donnerAlerte RAM ${tabOpt[0]}  / octets limite pour l'alerte  ${tabOpt[1]} "

  #CAPTURE DE LA RAM
  ram=$(free -b)
  read -ra tabRam -d $'\0' <<< "$ram"
  mysql -u "raspi" -D "raspi_general" -s -N  -e "INSERT INTO ram (utilisee, partagee, buff_cache) VALUES ('${tabRam[8]}', '${tabRam[10]}', '${tabRam[11]}')"

  #CAPTURE DE LA TEMPERATURE
  temperature=$(bc <<< "scale = 1; $(cat /sys/class/thermal/thermal_zone0/temp) / 1000")
  mysql -u "raspi" -D "raspi_general" -e "INSERT INTO temp_log (temperature) VALUES ($temperature)"

  #gestion d'alerte température
  if (( ${tabOpt[2]} == 1 ))
  then
    if (( $(echo "${tabOpt[3]} < $temperature" |bc -l) )) && [ $t_alert == false ]
    then
      echo "on donne l'alerte : ${tabOpt[3]} < $temperature."
      wget -q --spider  "https://smsapi.free-mobile.fr/sendmsg?user=22683416&pass=LslzRq4Tz04fDE&msg=Alerte sur le raspi : la température du processeur ets supérieure à ${tabOpt[3]} °C. Température actuelle : $temperature °C"
      t_alert=true
    elif (( $(echo "${tabOpt[3]} - (10 * ${tabOpt[3]} / 100) > $temperature" |bc -l)  )) && [ $t_alert == true ]
    then
      echo "fin de l'alerte"
      t_alert=false
    fi
  fi


  #check de l ordre de fréquence horloge
  bddHorloge=$(mysql -u "raspi" -D "raspi_general" -s -N  -e "SELECT valeur FROM opt WHERE nom_opt = 'monitoring_frequence'")
  if (( $bddHorloge > 0 ));
  then
    horloge=$bddHorloge
  fi

  sleep $horloge

  #check de l ordre d arrêt
  if [ $(mysql -u "raspi" -D "raspi_general" -s -N  -e "SELECT valeur FROM opt WHERE nom_opt = 'monitoring_run'") != $pid ]
  then
    run=false
  fi
done
echo "commande de sortie de boucle"
mysql -u "raspi" -D "raspi_general" -s -N  -e "UPDATE opt SET valeur = '0'  WHERE nom_opt = 'monitoring_run'"


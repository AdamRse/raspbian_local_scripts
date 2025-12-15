#!bin/bash
pid=$$
allumer=false
tempsAttente=2400
cycles=0

function obtenir_opt()
{
  echo $(mysql -u "raspi" -D "raspi_general" -N -r -e "SELECT valeur FROM opt WHERE nom_opt = 'lampe_run_cycle' OR nom_opt = 'lampe_decalage'")
}
function jour()
{
  echo $(mysql -u "raspi" -D "raspi_general" -N -r -e "SELECT lever, coucher FROM cycle_jour_nuit WHERE journee = '$dtId'")
}

run=true
mysql -u "raspi" -D "raspi_general" -s -N  -e "UPDATE opt SET valeur = '$pid' WHERE nom_opt = 'lampe_run_cycle'"

#Le programme annonce son lancement physiquement par un switch
bash /home/adam/dev/projets/raspbian_local_scripts/lampe_switch_pi_OS.sh 22
sleep 1
bash /home/adam/dev/projets/raspbian_local_scripts/lampe_switch_pi_OS.sh 22

while $run; do
  cycles=$((cycles+1))
  dtId=$(date +%d%m)
  aujourdhui=$(date +%F)
  ligne_opt=$(obtenir_opt)
  ligne_jour=$(jour)

#  echo "ligne OPT : "$ligne_opt
#  echo "ligne JOUR : "$ligne_jour

#  IFS=" "
  read -ra tabJour <<< "$ligne_jour"
  read -ra tabOpt <<< "$ligne_opt"

  bddRun=${tabOpt[1]}
  decalage=${tabOpt[0]}
  leverJour=${tabJour[0]}
  coucherJour=${tabJour[1]}


  secNow=$(date +%s)
  secLever=$(date -d $leverJour +%s)
  secCoucher=$(date -d $coucherJour +%s)

  #si secnow<leverjour alors on désactive la lampe le prochain lever du soleil
  #-lt inferieur à
  if (( secNow < ( secLever + decalage ) )); then
    tempsAttente=$(( $secLever - $secNow + $decalage ))
    allumer=false
  elif (( secNow < ( secCoucher - decalage ) )); then
    tempsAttente=$(( $secCoucher - $secNow - $decalage ))
    allumer=true
  else
    #On est dans la nuit, on active au lever suivant
    demainId=$(date --date="+1 day" +%d%m)
    demainDate=$(date --date="+1 day" +%Y-%m-%d)
    leverDemain=$(mysql -u "raspi" -D "raspi_general" -N -r -e "SELECT lever FROM cycle_jour_nuit WHERE journee = '$demainId';")
    secDemain=$(date -d "$demainDate $leverDemain" +%s)
    tempsAttente=$(( $secDemain - $secNow - $decalage ))
    allumer=false
  fi

  echo "--- Programme cycle_jour, cycle $cycles, $(date '+%d/%m/%Y') :"
  echo -e "\tsecLever \t$secLever\t"$(date --date="@$secLever" +%H:%M:%S)
  echo -e "\tsecCoucher\t$secCoucher\t"$(date --date="@$secCoucher" +%H:%M:%S)
  echo -e "\tsec now  \t$secNow\t"$(date --date="@$secNow" +%H:%M:%S)
  echo -e "\tattente \t$tempsAttente\t\t"$(date --date="@$(( tempsAttente - 3600 ))" +%H:%M:%S)
  echo -e "\tbasculement\t$allumer"
  echo -e "\t---"
  if [ $bddRun != $pid ];
  then
    echo -e "\tDemande de sortie de la boucle"
    run=false
  else
    echo "[ATTENTE : $tempsAttente]"
    sleep $tempsAttente
    if [ $(mysql -u "raspi" -D "raspi_general" -N -r -e "SELECT valeur FROM opt WHERE nom_opt = 'lampe_run_cycle'") == $pid ];
    then
      skip=$(mysql -u "raspi" -D "raspi_general" -N -r -e "SELECT valeur FROM opt WHERE nom_opt = 'lampe_run_skip'")
      if [ $skip == "0" ];
      then
        if $allumer; then
          echo "[ALLUMAGE]"
          echo "2" > /sys/class/gpio/export
          bash /home/adam/dev/projets/raspbian_local_scripts/lampe_switch_pi_OS.sh 22 1
        else
          echo "[ARRET]"
          echo "2" > /sys/class/gpio/export
          bash /home/adam/dev/projets/raspbian_local_scripts/lampe_switch_pi_OS.sh 22 0
        fi
        else
          if [ $skip == 1 ];
          then
            mysql -u "raspi" -D "raspi_general" -s -N  -e "UPDATE opt SET valeur = '0' WHERE nom_opt = 'lampe_run_skip'"
            echo -e "Annulation ponctuelle de l'ordre de basculement. Le prochain basculement sera effectué."
          else
            echo -e "Annulation permanente de l'ordre de basculement. Le programme reste actif et testera à nouveau l'ordre d'annulation au prochan basculement (configuration manuelle nécéssaire pour rétablissement)."
          fi
          sleep 2
        fi
    else
      run=false
      echo -e "Arrêt du programme, le PID en base de données n'est pas le même que le programme."
    fi
  fi

done
echo -e "[Fin de programme]"
mysql -u "raspi" -D "raspi_general" -s -N  -e "UPDATE opt SET valeur = '0' WHERE nom_opt = 'lampe_run_cycle'"

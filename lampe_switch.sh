#!bin/bash
############
#PARAMETRES
# $1 : id du GPIO
# $2 : on/off (0/1)
############

#normal=true va servir à déterminer si le gpui a été fermé correctement de façon à éviter un double switch
normal=true


if [ ! -f "/sys/class/gpio/gpio$1/value" ]; then
  echo "$1" > /sys/class/gpio/export
fi
if [ ! -f "/sys/class/gpio/gpio$1/direction" ]; then
  echo "out" > /sys/class/gpio/gpio$1/direction
elif [ $(cat /sys/class/gpio/gpio$1/direction) == "in" ]; then
  #on bascule la direction sur out, ce qui va provoquer un switch
  #on ignorera don la commande de switch via $normal
  normal=false;
  echo "out" > /sys/class/gpio/gpio$1/direction
fi

if [ -z "$2" ]; then
  #On si le gpio a été mal fermé (avec sa valeur active, sans unexport), le positionneent sur out a déjà switché, on évite de re-switcher
  if $normal; then
    if [ $(cat /sys/class/gpio/gpio$1/value) == "0" ]; then
      echo "1" > /sys/class/gpio/gpio$1/value
    else
      echo "0" > /sys/class/gpio/gpio$1/value
    fi
  fi
 else
  if [ $2 == "1" ]; then
    echo "0" > /sys/class/gpio/gpio$1/value
  elif [ $2 == "0" ]; then
    echo "1" > /sys/class/gpio/gpio$1/value
  else
    echo "Argument $1 incompris"
  fi
fi
#echo "3" > /sys/class/gpio/unexport

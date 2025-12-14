#!/bin/bash
############
#PARAMETRES
# $1 : id du GPIO (numérotation BCM : 22, 17, 4, etc.)
# $2 : on/off (0/1) [optionnel]
############

# Conversion BCM vers SYSFS (nouvelle numérotation)
GPIO_SYSFS=$((512 + $1))

# normal=true va servir à déterminer si le gpio a été fermé correctement de façon à éviter un double switch
normal=true

if [ ! -f "/sys/class/gpio/gpio$GPIO_SYSFS/value" ]; then
  echo "$GPIO_SYSFS" > /sys/class/gpio/export
fi

if [ ! -f "/sys/class/gpio/gpio$GPIO_SYSFS/direction" ]; then
  echo "out" > /sys/class/gpio/gpio$GPIO_SYSFS/direction
elif [ $(cat /sys/class/gpio/gpio$GPIO_SYSFS/direction) == "in" ]; then
  # on bascule la direction sur out, ce qui va provoquer un switch
  # on ignorera donc la commande de switch via $normal
  normal=false
  echo "out" > /sys/class/gpio/gpio$GPIO_SYSFS/direction
fi

if [ -z "$2" ]; then
  # On vérifie si le gpio a été mal fermé (avec sa valeur active, sans unexport), le positionnement sur out a déjà switché, on évite de re-switcher
  if $normal; then
    if [ $(cat /sys/class/gpio/gpio$GPIO_SYSFS/value) == "0" ]; then
      echo "1" > /sys/class/gpio/gpio$GPIO_SYSFS/value
    else
      echo "0" > /sys/class/gpio/gpio$GPIO_SYSFS/value
    fi
  fi
else
  if [ "$2" == "1" ]; then
    echo "1" > /sys/class/gpio/gpio$GPIO_SYSFS/value
  elif [ "$2" == "0" ]; then
    echo "0" > /sys/class/gpio/gpio$GPIO_SYSFS/value
  else
    echo "Argument $2 incompris"
  fi
fi

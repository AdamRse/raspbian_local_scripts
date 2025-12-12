#!bin/bash

function fonction()
{
    
}
variable=$(fonction)

html=$(wget -qO - "https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/roanne/tomorrow?unitGroup=metric&include=hours&key=TSPF6KJAMXNW6DGBFKW9UKAVA&contentType=csv")
#rl=read line
rl=7

IFS=$'\n' lines=($html)
echo ${lines[$rl]}


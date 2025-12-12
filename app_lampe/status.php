<?php
require '/var/www/bibliotheque/pi/intrusion.php';

if(!intrus){
    $stat=0;
    if(file_exists("/sys/class/gpio/gpio3/value")){
        $val = exec('echo $(cat /sys/class/gpio/gpio3/value)');
        $direction = exec('echo $(cat /sys/class/gpio/gpio3/direction)');
        //var_dump($direction, $val);
        if($direction=="out" && $val=="0")
            $stat=1;
    }
    echo $stat;
}
<?php

function switchgpio($gpio, $force = null){
    $b1 = exec('echo "'.$gpio.'" > /sys/class/gpio/export', $out1, $err1);
    $b2="Le gpio$gpio n'a pas pu être ouvert (".__FILE__." ligne ".__LINE__.")";
    if(file_exists("/sys/class/gpio/gpio".($gpio+512)."/value")){
        if($force===null)
            $b2 = exec('bash /home/adam/dev/projets/raspbian_local_scripts/lampe_switch_pi_OS.sh '.$gpio, $out2, $idErr2);
        else
            $b2 = exec('bash /home/adam/dev/projets/raspbian_local_scripts/lampe_switch_pi_OS.sh '.$gpio.' '.$force, $out2, $idErr2);
    }
    return empty($b2)?true:$b2;
}

//if(!intrus){
    $ok=null;
    foreach($_GET as $gpio => $val){
        if($ok === null){
            if(is_numeric($gpio) && (empty($val) || $val == "1")){
                $ok = switchgpio($gpio, $val);
            }
            else
                $ok="GPIO ou sa valeur passé en paramètre GET non valide ([$gpio] => '$val').";
        }
    }
    echo (empty($ok))?"1":$ok;
//}

<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

$couleurNormal="#080";
$couleurW1="#c07428";
$couleurW2="#800";

$msqli=new mysqli("localhost", "raspi", "", "raspi_general");
$retour=array();

function getCouleur($val, $limit1, $limit2){
    global $couleurNormal;
    global $couleurW1;
    global $couleurW2;
    if($val<$limit1){
        $couleur=$couleurNormal;
    }
    else if($val<$limit2){
        $couleur=$couleurW1;
    }
    else{
        $couleur=$couleurW2;
    }
    return $couleur;
}

if(!empty($_GET['f']) && $frequence = (int)$_GET['f']){
    if($frequence<=10000){
        $tmpWarning_1 = false; $tmpWarning_2 = false;
        $tmpWarning = $msqli->query("SELECT valeur FROM opt WHERE nom_opt = 'temperature_warning_1' OR nom_opt = 'temperature_warning_2'");
        while($twfetch = $tmpWarning->fetch_row()){
            if($tmpWarning_1) $tmpWarning_2 = $twfetch[0];
            else $tmpWarning_1 = $twfetch[0];
        }
        if(isset($_GET['update'])){
            $logTmp = $msqli->query("SELECT temperature, timestamp FROM temp_log ORDER BY id DESC LIMIT 0, $frequence");
            $valHaute=0; $ts = 0;
            while($row=$logTmp->fetch_assoc()){
                if($row['temperature']>$valHaute){ $valHaute=$row['temperature']; $ts=$row['timestamp']; }
            }
            
            $retour["graph"] = array("data" => $valHaute, "label" => explode(" ", $ts)[1], "couleur" => getCouleur($valHaute, $tmpWarning_1, $tmpWarning_2));
        }
        else{
            if(!empty($_GET['p']) && $periode = (int)$_GET['p']){
                $tmpWarning_1 = false; $tmpWarning_2 = false;
                $tmpWarning = $msqli->query("SELECT valeur FROM opt WHERE nom_opt = 'temperature_warning_1' OR nom_opt = 'temperature_warning_2'");
                while($twfetch = $tmpWarning->fetch_row()){
                    if($tmpWarning_1) $tmpWarning_2 = $twfetch[0];
                    else $tmpWarning_1 = $twfetch[0];
                }
                $logTmp = $msqli->query("SELECT a.temperature, a.timestamp FROM (SELECT b.* FROM temp_log as b ORDER BY b.id DESC LIMIT 0, ".(($periode>86400)?86400:$periode).") as a ORDER BY a.id ASC");
                $tabReponse=array();
                $i=0; $plusHaute=array(0);
                $retourTemp = array();
                $retourDate = array();
                $retourCouleur = array();
                $tmpMin=1000;
                $tmpMax=0;
                while(($periode+$i)%$frequence!=0){
                    $i++;
                }
                while($row=$logTmp->fetch_assoc()){
                    $i++;
                    if($row['temperature']>$plusHaute[0]){
                        $plusHaute=array($row['temperature'], explode(" ", $row['timestamp'])[1]);
                    }
                    if($i>=$frequence){
                        $retourTemp[]=$plusHaute[0];
                        $retourDate[]=$plusHaute[1];
                        $retourCouleur[]= getCouleur($plusHaute[0], $tmpWarning_1, $tmpWarning_2);
                        if($plusHaute[0]>$tmpMax) $tmpMax=$plusHaute[0];
                        else if($plusHaute[0]<$tmpMin) $tmpMin=$plusHaute[0];
                        
                        $plusHaute=array(0);
                        $i=0;
                    }
                }
                
                $retour["graph"]["data"]=$retourTemp;
                $retour["graph"]["label"]=$retourDate;
                $retour["graph"]["couleur"]=$retourCouleur;
                $retour["graph"]["min"]=$tmpMin;
                $retour["graph"]["max"]=$tmpMax;
            }
            else{
                $retour["erreur"][]="Une periode 'p' (en secondes, max 60*60*24) doit être envoyée";
            }
        }
    }
    else
        $retour['erreur'][]="La fréquence ne peut pas être suppérieur à 10 000.";
}
else{
    $retour["erreur"][]="Une fréquence 'f' (en secondes) doit être envoyée";
}
echo json_encode($retour);

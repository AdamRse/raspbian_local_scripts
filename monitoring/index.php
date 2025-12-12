<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

session_start();

require '/var/www/bibliotheque/pi/intrusion.php';

function affiche_temp_couleurs($txtTemp){
    preg_match("/.*([1-9][0-9]\.[0-9][0-9]?).*/", $txtTemp, $match);
        $tFloat=(isset($match[1]))?$match[1]:0;
    $spCl="actif";
    if($tFloat>54) $spCl="inactif";
    elseif($tFloat>43) $spCl="warning";
    //return "<span class='$spCl'>$txtTemp</span>";*
    return str_replace($tFloat, "<span class='$spCl' style='font-weight: bolder'>$tFloat</span>", $txtTemp);
}


$r=exec("bash /home/pi/scripts/cpuTemperature.sh");
$dtime= time();
$msqli=new mysqli("localhost", "raspi", "", "raspi_general");

$result = $msqli->query("SELECT nom_opt, valeur FROM opt");
$tabOpt=array();
while($row = $result->fetch_assoc()){
    $tabOpt[$row["nom_opt"]]=$row["valeur"];
}
$tabJour=array();
$rqJour = $msqli->query("SELECT * FROM cycle_jour_nuit WHERE journee = '".date("dm", $dtime-86400)."' OR journee = '".date("dm")."' OR journee = '".date("dm", $dtime+86400)."'");
while($row = $rqJour->fetch_assoc()){
    $tabJour[]=$row;
}

$rqCoucher = $msqli->query("SELECT lever FROM cycle_jour_nuit WHERE journee = '".date("dm", $dtime+86400)."'");
$demain = $rqJour->fetch_assoc();
//$rqCoucher = $msqli->query("SELECT lever FROM cycle_jour_nuit WHERE journee = '".date("dm", $dtime+86400)."'");
//$demain = $rqJour->fetch_assoc();

$logTmp = $msqli->query("SELECT temperature, timestamp FROM temp_log ORDER BY id DESC LIMIT 0, 3600");


if(!intrus){
?>
<!DOCTYPE html>
<html>
<head>
    <title>Serveur ORI </title>
    <link rel="stylesheet" href="css.css">
    <link rel="icon" type="image/png" href="ico.png" />
    <script src="./lib/chart.js/index.js"></script>
</head>
<body>
    <p><?php echo strftime('%d / %m / %Y - %H:%M:%S'); ?>
        <br/>Ensoleillement : <?php echo $tabJour[1]["duree_jour"] ?></p>
    <h1>Ori</h1>
    <ul>
        <h2>Stockage</h2>
    <?php
    $splitDf= explode(" ", exec("df -h /"));    
    echo "<li>Stockage : ".((empty($splitDf[10]))?$splitDf[11]:$splitDf[10])."o / ".((empty($splitDf[8]))?$splitDf[14]:$splitDf[8])."o (".((empty($splitDf[15]))?$splitDf[16]:$splitDf[15]).")</li>";
    echo "<li>Espace libre : ".((empty($splitDf[13]))?$splitDf[14]:$splitDf[13])."o</li>";
    ?>
    </ul>
    <h1>Température du processeur</h1>
    <div class="chart-container" style="position: relative; height: 130px;">
        <canvas id="chart"></canvas>
    </div>
    <h1>Monitoring</h1>
    <ul>
        <h2>Lampe</h2>
        <li>Allumage et arrêt automatique : <?php
        if($tabOpt['lampe_run_cycle']=="0" || $tabOpt['lampe_run_cycle']=="out"){
            echo "<span class='inactif'>Désactivé</span>";
        }
        else{
            if(is_dir('/proc/'.$tabOpt['lampe_run_cycle'])){
                echo "<span class='actif'>Activé</span>";
                echo "</li>";
                $split=explode(':', $tabJour[1]['coucher'].date(":m:d:Y"));
                $coucherDt = mktime($split[0], $split[1], $split[2], $split[3], $split[4], $split[5]);
                $tempsBasculement=null;
                if(($coucherDt-$dtime+$tabOpt['lampe_decalage'])>0){
                    $split=explode(':', $tabJour[1]['lever'].date(":m:d:Y"));
                    $leverDt = mktime($split[0], $split[1], $split[2], $split[3], $split[4], $split[5]);
                    if(($leverDt-$dtime-$tabOpt['lampe_decalage'])>0)
                        $tempsBasculement=date("H:i:s", $leverDt-$dtime-3600-$tabOpt['lampe_decalage']);
                    else
                        $tempsBasculement=date("H:i:s", $coucherDt-$dtime-3600+$tabOpt['lampe_decalage']);
                }
                else{
                    $split=explode(':', $tabJour[2]['lever'].date(":m:d:Y", $dtime+86400));
                    $leverDemainDt = mktime($split[0], $split[1], $split[2], $split[3], $split[4], $split[5]);
                    $tempsBasculement=date("H:i:s", $leverDemainDt-$dtime-3600-$tabOpt['lampe_decalage']);
                }
                echo "<li>Temps avant basculement : $tempsBasculement</li>";
                
            }
            else{
                $msqli->query("UPDATE opt SET valeur = '0' WHERE nom_opt = 'lampe_run_cycle'");
                echo "<span class='inactif'>Désactivé</span>";
            }
        }
        ?></li>
        <li>Décalage du cycle : <?php echo date("H:i:s", $tabOpt['lampe_decalage']-3600) ?></li>
    </ul>
    <ul>
        
        <h2>Température</h2>
        <?php
        if(is_dir('/proc/'.$tabOpt['monitoring_run'])){
            echo '<li>Contrôle de la température : <span class="actif">Activé</span></li>';
            ?>
            <li>Fréquence de relevé de la température : <?php echo $tabOpt['monitoring_frequence'].(($tabOpt['monitoring_frequence']>1)?" secondes":" seconde") ?></li>
            <li>Seuil critique de température : <?php echo $tabOpt['temperature_warning_alert_trigger_limit'] ?>°C</li>
            <li>Alerte seuil critique de température :
            <?php echo ($tabOpt['temperature_warning_alert_trigger']=="0")?"<span class='inactif'>Désactivée</span>":"<span class='actif'>Activée</span>" ?></li>
            <?php
        }
        else
            echo '<li>Contrôle de la température : <span class="inactif">Désactivée</span></li>';
        ?>
        
    </ul>
    <h1>Sites</h1>
    <p><a href="http://adamrousselle.ddns.net/app_lampe/">Contrôle de la lampe</a></p>
    <script src="js.js"></script>
    <script src="graph.js"></script>
</body>
</html> 
<?php
}
else
    header('location: https://www.https://www.google.com/search?q=pizeunrvpirtrth');
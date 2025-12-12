<?php
require '/var/www/bibliotheque/pi/intrusion.php';
if(!intrus){
    $msqli=new mysqli("localhost", "raspi", "", "raspi_general");
    $rqSkip=$msqli->query("SELECT valeur FROM opt WHERE nom_opt = 'lampe_run_skip'");
    $skip=(int)$rqSkip->fetch_row()[0];
?>
<!DOCTYPE html>
<html>
<head>
    <title>Contrôle de la lampe</title>
    <link rel="stylesheet" href="css.css">
    <link rel="icon" type="image/png" href="icoOmori.png" />
</head>
<body>
    <h1>Contrôle de la lampe</h1>
    <button id="switch_Lampe1" class="btSwitch" onclick="switchLampe(22)">Ambiance</button>
    <button id="switch_Lampe2" class="btSwitch" onclick="switchLampe(27)">Plafond</button>
    <div id="status">00</div>
    <h3>Bascule automatique</h3>
    <div id="bt0" class="bouton vert-<?php echo ($skip==0)?"run":"stop" ?>" onclick="clicBascule(0)"></div>
    <div id="bt1" class="bouton orange-<?php echo ($skip==1)?"run":"stop" ?>" onclick="clicBascule(1)"></div>
    <div id="bt2" class="bouton rouge-<?php echo ($skip==2)?"run":"stop" ?>" onclick="clicBascule(2)"></div>
    <p id="statusSkip"><?php if($skip>0){
        echo ($skip=="1")?"Le prochain baculement sera ignoré.":"Basculement automatique désactivé.";
    }
    else
        echo "Basculement automatique activé.";
        ?></p>
    <script src="js.js"></script>
</body>
</html>
<?php
}

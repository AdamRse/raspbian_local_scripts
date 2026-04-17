<?php
require "env.mysqli.php";
// env.mysqli.php contient :
// $mysqli = new mysqli(
//     "host",
//     "user",
//     "password",
//     "database",
// );

$result = $mysqli->query("SELECT nom_opt, valeur FROM opt WHERE nom_opt = 'lampe_decalage' OR nom_opt = 'lampe_run_skip_allumage' OR nom_opt = 'lampe_run_skip_arret' OR nom_opt = 'lampe_run_suspend'",);
$options_bdd = [];
while($rt = $result->fetch_row()) {
    $options_bdd[$rt[0]] = $rt[1];
}

// echo "<pre>";
// var_dump($options_bdd);
// echo "</pre>";
?>

<!DOCTYPE html>
<html>
<head>
    <title>Contrôle de la lampe</title>
    <link rel="stylesheet" href="css.css">
    <link rel="icon" type="image/png" href="icoOmori.png" />
</head>
<body>
    <div id="wrapper">
        <h1>Contrôle de la lampe</h1>
        <button id="switch_Lampe1" class="btSwitch" onclick="switchLampe(22)">Switch lampe</button>
        <div id="status">00</div>
        <h3>Mode</h3>
        <div id="bt_dashboard">
            <div id="bt0" class="bouton vert-<?= $options_bdd["lampe_run_suspend"]==0?"run":"stop" ?>" onclick="clicBascule(0)"></div>
            <div>
                <div id="bt1" class="bouton orange-stop" onclick="clicBascule(1)">
                    <input type="text" value="<?= $options_bdd["lampe_run_skip_allumage"] ?>"/>
                </div>
                Lever
            </div>
            <div>
                <div id="bt2" class="bouton orange-stop" onclick="clicBascule(2)">
                    <input type="text" value="<?= $options_bdd["lampe_run_skip_arret"] ?>"/>
                </div>
                Coucher
            </div>
            <div id="bt3" class="bouton rouge-<?= $options_bdd["lampe_run_suspend"]==1?"run":"stop" ?>" onclick="clicBascule(3)"></div>
        </div>
        <div class="decallage">
            <h3>Décallage manuel</h3>
            <input type="number" min="0" value="<?= $options_bdd["lampe_decalage"] ?>"/>
            <button>Valider</button>
        </div>
        <p id="statusSkip">

        </p>
    </div>
    <script src="js.js"></script>
</body>
</html>

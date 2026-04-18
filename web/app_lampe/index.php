<?php
// Empêcher la mise en cache pour tous les navigateurs
header("Cache-Control: no-store, no-cache, must-revalidate, max-age=0");
header("Cache-Control: post-check=0, pre-check=0", false);
header("Pragma: no-cache"); // Pour la compatibilité avec HTTP/1.0
header("Expires: Wed, 11 Jan 1984 05:00:00 GMT"); // Une date passée

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

exec("systemctl is-active lampeur.service > /dev/null 2>&1", $output, $returnCode);
$serviceLampeActive=($returnCode==0);

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
$mysqli->close();

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
        <!-- Données BDD -->
        <input type="hidden" id="data"
            data-decallage="<?= $options_bdd["lampe_decalage"] ?>"
            data-skip_allumage="<?= $options_bdd["lampe_run_skip_allumage"] ?>"
            data-skip_arret="<?= $options_bdd["lampe_run_skip_arret"] ?>"
            data-suspend="<?= $options_bdd["lampe_run_suspend"] ?>"
        />
        <input type="hidden" id="requete_bdd"
            data-decallage="<?= $options_bdd["lampe_decalage"] ?>"
            data-skip_allumage="<?= $options_bdd["lampe_run_skip_allumage"] ?>"
            data-skip_arret="<?= $options_bdd["lampe_run_skip_arret"] ?>"
            data-suspend="<?= $options_bdd["lampe_run_suspend"] ?>"
        />
        <h1>Contrôle de la lampe</h1>
        <button id="switch_Lampe1" class="btSwitch" onclick="switchLampe(22)">Switch lampe</button>
        <div id="status">00</div>
        <h3>Mode</h3>
        <?php
        if (!$serviceLampeActive){
            ?>
            <div id="inactive-alert"><h3>Le service lampeur est arrêté !</h3>La programmation de la lampe ne fonctionnera que quand le service systemd lampeur sera relancé.</div>
            <?php
            }
        ?>
        <div id="bt_dashboard">
            <div id="bt-marche" class="diode vert-<?= $options_bdd["lampe_run_suspend"]==0?"run":"stop" ?>" onclick="clic_diode(this)"></div>
            <div>
                <div id="bt-skip-lever" class="diode orange-<?= $options_bdd["lampe_run_skip_allumage"]>0?"run":"stop" ?>" onclick="clic_diode(this)">
                    <input type="number" inputmode="numeric" min="0" data-champ_bdd="lampe_run_skip_allumage" data-default_val="<?= $options_bdd["lampe_run_skip_allumage"] ?>" value="<?= $options_bdd["lampe_run_skip_allumage"] ?>"/>
                </div>
                Lever
            </div>
            <div>
                <div id="bt-skip-coucher" class="diode orange-<?= $options_bdd["lampe_run_skip_arret"]>0?"run":"stop" ?>" onclick="clic_diode(this)">
                    <input type="number" inputmode="numeric" min="0" data-champ_bdd="lampe_run_skip_arret" data-default_val="<?= $options_bdd["lampe_run_skip_allumage"] ?>" value="<?= $options_bdd["lampe_run_skip_arret"] ?>"/>
                </div>
                Coucher
            </div>
            <div id="bt-suspend" class="diode rouge-<?= $options_bdd["lampe_run_suspend"]==1?"run":"stop" ?>" onclick="clic_diode(this)"></div>
        </div>
        <div class="decallage">
            <h3>Décallage manuel</h3>
            <input type="number" inputmode="numeric" min="0" value="<?= $options_bdd["lampe_decalage"] ?>"/>
            <button>Valider</button>
        </div>
        <p id="statusSkip">

        </p>
    </div>
    <script src="js.js"></script>
</body>
</html>

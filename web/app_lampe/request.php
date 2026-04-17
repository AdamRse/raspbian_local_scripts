<?php
require "env.mysqli.php";

$table=false;
$valeur=false;
foreach($_GET as $cle => $val){
    $table=$cle;
    $valeur=$val;
}

if ($table === false || $valeur === false) return "Clé/Valeur invalide : $cle/$valeur";

$request = "UPDATE opt SET valeur = '$valeur' WHERE nom_opt = '$cle'";
if ($mysqli->query($request))
    echo "1";
else
    echo "Mysqli renvoie une erreur : ".$mysqli->error;

$mysqli->close();

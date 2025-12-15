<?php
// require '/var/www/bibliotheque/pi/intrusion.php';

// if(!intrus){
    $msqli=new mysqli("localhost", "raspi", "", "raspi_general");
    if($msqli->query("UPDATE opt SET valeur = ".((isset($_GET['o']) && ($_GET['o']=="1" || $_GET['o']=="2"))?$_GET['o']:0)." WHERE nom_opt = 'lampe_run_skip'"))
        echo "1";
    else
        echo "0";
//}
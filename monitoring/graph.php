<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

?>
<!DOCTYPE html>
<html>
<head>
    <title>Serveur ORI </title>
    <link rel="stylesheet" href="css.css">
    <link rel="icon" type="image/png" href="img/icon.png" />
    <script src="./lib/chart.js/index.js"></script>
</head>
<body>
    <h1>Graphique</h1>
    <div class="chart-container" style="position: relative; height: 130px;">
        <canvas id="chart"></canvas>
    </div>

    <script src="graph.js"></script>
    <script>
        
    
    //setTimeout(function(){ updateData(myChart, "19:550", "rgba(0, 200, 0, 1)", 10) }, 2000);
    </script>

</body>
</html>
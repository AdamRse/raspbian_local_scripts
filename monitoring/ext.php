<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

session_start();

require '/var/www/bibliotheque/pi/intrusion.php';

$msqli=new mysqli("localhost", "raspi", "", "raspi_general");

$result = $msqli->query("SELECT * FROM info_acces_externe ORDER BY id DESC LIMIT 0, 800");
$tab=array();


if(!intrus){
?>
<!DOCTYPE html>
<html>
<head>
    <title>Serveur ORI </title>
    <style>
        .unit{
            margin-bottom: 10px;
        }
        .unit .appercu{
            background-color: #ccc;
            margin: 5px 15px;
            cursor: pointer;
        }
        .unit .detail{
            width: 50%;
            display: inline-block;
            vertical-align: top;
        }
        .unit .hidden{
            display: none;
        }
    </style>
</head>
<body>
    <h1>Acces externe</h1>
    <?php
    while($row = $result->fetch_assoc()){
        ?>
        <div class="unit">
            <div class="appercu" onclick="toggleDiv(this)"><?php echo '['.$row['id'].'] '.$row['time'].' ('.$row['ip'].')' ?></div>
            <div class="detail hidden">
                <h2>Serveur info</h2>
                <?php 
                $serv=unserialize($row['info_server']);
                foreach ($serv as $key => $value) {
                    echo '<p><b>['.$key.']</b> '.$value.'</p>';
                }
                ?>
            </div><div class="detail hidden">
                <h2>header info</h2>
                <?php 
                $head=unserialize($row['info_header']);
                foreach ($head as $key => $value) {
                    echo '<p><b>['.$key.']</b> '.$value.'</p>';
                }
                ?>
            </div>
        </div>    
        <?php
    }
    ?>
    <script>
        function toggleDiv(e){
            console.log("Je toggle l'element", e)
            var detail = e.parentNode.querySelectorAll(".detail");
            detail[0].classList.toggle("hidden");
            detail[1].classList.toggle("hidden");
        }
    </script>
</body>
</html> 
<?php
}
else
    header('location: https://www.youtube.com/watch?v=ThTYVpaLqTU');
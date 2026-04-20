<?php
// Ajouter un env.mysqli.php qui initialise la connexion mysqli comme ce qui suit.
// La base de données à installer est disponible dans ./bdd/raspi_general.sql
$mysqli = new mysqli(
    "host",
    "user",
    "password",
    "raspi_general",
);

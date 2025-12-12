<?php
//Savoir si on permet le changement de versions de logiciels mis à jour peu fréquement comme les OS
function creerRegexVersioning($HauteRestriction=true, &$err = array()){
    $retour=false;
    $usAg=$_SERVER['HTTP_USER_AGENT'];

    //Délimiteurs regex de logiciels souvent mis à jour
    $listeDelimiteurHauteFrequence=array(
        "firefox/", "gecko/", "chrome/", " edg/", "keeper/", " rv:", "webkit/", "safari/", "samsungBrowser/", "musical_ly_", ".zc."
    );

    //Délimiteurs regex de logiciels moins mis à jour
    $listeDelimiteurBasseFrequence=array(
        " os ", "crios/", "webview", "version/"
    );

    //On prend seulement les appareils à haute fréquence de version, ou tous
    if($HauteRestriction){
        $listeDelimiteurs=array_merge($listeDelimiteurHauteFrequence,$listeDelimiteurBasseFrequence);
    }
    else{
        $listeDelimiteurs=$listeDelimiteurHauteFrequence;
    }
    $listeDelInline="";

    //Construction de la partie délimiteur de la regex
    foreach ($listeDelimiteurs as $value) {
        $listeDelInline.="|". str_replace(array("/", "."), array("\/", "\."), $value);
    }

    //Construction de la regex pour trouver les versions et leur délimiteur
    $regexMatchNum="(".substr($listeDelInline, 1).")[0-9]+((\.|\_)[0-9]+)*";

    //Execturion de la regex dans un try, pour récupérer une potentielle erreur e_warning
    try{
        preg_match_all("/$regexMatchNum/i", $usAg, $matches);
    }
    catch(Exception $e){
        $err[]=$e->getMessage()." - REGEX : $regexMatchNum";
    }

    //Pour chaque match ($value) on a la version du logiciel et son délimiteur
    foreach ($matches[0] as $value){
        //Pas de vérification de $value car il ne peut pas être nul, la regex ne peut pas être en erreur car elle a déjà été testée dans le preg_match_all précédent

        //Extraction de la version, séparée de son délimiteur (dans $numberMatch)
        preg_match("/[0-9]+((\.|\_)[0-9]+)*/i", $value, $numberMatch);

        //On remet le délimiteur dans l'userAgent, mais on remplace le numéro de version par un marqueur
        $ex=explode($value, $usAg, 2);
        $usAg=$ex[0].str_replace($numberMatch[0], "#:numVer", $value).$ex[1];
    }

    //On créer une regex à partir de l'userAgent (modifié avec des marqueurs à la place des versions détectée
    $regexUA= str_replace(array("\\", ".", "/", "(", ")", "?", "+", "-", "|", "*", "[", "]", "{", "}", "^", "$", "#:numVer")
            , array("\\\\", '\.', "\/", "\(", "\)", "\?", "\+", "-", "\|", "\*", "\[", "\]", "\{", "\}", "\^", "\$", "([0-9]+(\.[0-9]+)*)")
            , $usAg);

    //On vérifie si la regex fonctionne sur l'userAgent actuel
    try{
        if(($testRegex = preg_match("/$regexUA/i", $_SERVER['HTTP_USER_AGENT']))===1){
            //La regex a bien été créée et est fonctionelle : $regexUA
            $retour = $regexUA;
        }
    }
    catch(Exception $e){
        $err[]=$e->getMessage();
    }
    return $retour;
}
$a=creerRegexVersioning();
echo "<p>$a</p>";
var graph = document.getElementById("graph");
var donnees = document.querySelectorAll("#donnees span");
var nbDonnees = donnees.length;
var ratio = 1;
var largeurGraph = graph.offsetWidth*ratio/nbDonnees;
var hauteurGraph = graph.offsetHeight;
var minimize=(largeurGraph>=1)?false:true;
while(minimize){
    ratio++;
    if(graph.offsetWidth*ratio/nbDonnees>=1){
        minimize=false
        largeurGraph=graph.offsetWidth*ratio/nbDonnees;
    }
    if(ratio>=2000){
        console.log("erreur, impossible de trouver le bon ratio");
        minimize=false;
        nbDonnees=0;
    }
}

//calculer l'échelle (var max et min)
var maxT = 0;
var minT = 100;
for(var i = 0;i<nbDonnees;i++){
    if(i%ratio==0){
        var t = donnees[i].innerHTML;
        if(maxT<t) maxT=Number(t);
        else if(minT>t) minT=Number(t);
    }
}
var zoom=minT-1;

//remplire l'axe des ordonnées
var ordonnees = document.querySelector("#contGraph .ordonnee_val");
var nbOrdonnees = 4;
for(var i=0;i<nbOrdonnees;i++){
    var contVal = document.createElement("div");
    contVal.classList.add("contVal");
    var valO = document.createElement("div");
    valO.className="val val"+i;
    valO.innerHTML = maxT;
    contVal.prepend(valO);
    ordonnees.prepend(contVal);
}

//remplir le graph
var reserve=[];
for(var i = 0;i<nbDonnees;i++){
    var t = Number(donnees[i].innerHTML);
    if(i%ratio==0){
        if(reserve.length>0){
            for(var j = 0;j<reserve.length;j++){
                if(t<reserve[j]) t=reserve[j];
            }
            reserve=[];
        }
        var hauteur = (t-zoom)*hauteurGraph/(maxT-zoom);
        var e = document.createElement("div");
        e.id="e_"+donnees[i].id.split("_")[1];
        e.classList.add("barre");
        e.style.width=largeurGraph+"px";
        e.style.height=hauteur+"px";
        e.innerHTML = t;
        if(t>=55) e.classList.add("chaud");
        else if(t<43) e.classList.add("froid");
        else e.classList.add("tiede");
        graph.prepend(e);
    }
    else
        reserve.push(t);
}
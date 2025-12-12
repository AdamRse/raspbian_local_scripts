//Valeur de retour attendue pour le graph :
//[graph]
//      [min] valeur data minimum
//      [max] valeur data maximum
//      [label][] valeur en abcisse
//      [data][] valeur en ordonnée
//      (optionel) [couleur][]  couleur de la data (Si ce tableau n'existe pas, par défaut la couleur sera noir)

////////////

//précision ET fréquence de rafraichissement du graphique en seconde
const frequence = 10;
//Période du graphique en seconde
const periode = 3600;
//Taille de la bordure entre 2 points du graphique
const bordure = 0;

////////////

var ctx = document.getElementById('chart').getContext('2d');
var rq = new XMLHttpRequest();
rq.open("GET", "./get_graph.php?p="+periode+"&f="+frequence);
rq.onload = function(){
    if(this.readyState === 4){
        try{ var rep = JSON.parse(this.response); }
        catch(e){
            var rep = {erreur:["Erreur de retour, le script ne renvoie pas un objet JSON parsable.\n\nRetour du script :\n"+this.response]};
        }
        
        if(rep.erreur===undefined){
            LancerGraph(rep.graph);
        }
        else{
            const nbErr = rep.erreur.length;
            const ligneErreur="retour d'erreur"+((nbErr>1)?"s":"")+" sur le graphique.";
            console.log(ligneErreur);
            ctx.innerHTML = ligneErreur;
            for(var i=0; i<nbErr; i++){
                console.log(rep.erreur[i]);
                ctx.innerHTML += "<br/>"+rep.erreur[i];
            }
        }
    }
}
rq.send();

function updateData(chart, label, bgColor, data){
    chart.data.labels.shift();
    chart.data.datasets.forEach((dataset) => {
        dataset.data.shift();
        dataset.backgroundColor.shift();
    });
    chart.data.labels.push(label);
    chart.data.datasets.forEach((dataset) => {
        dataset.data.push(data);
        dataset.backgroundColor.push(bgColor);
    });

    chart.update();
}
function LancerGraph(donnees){
    if(donnees.couleur==undefined){
        donnees["couleur"]="#000";
    }
    var myChart = new Chart(ctx, {
        type: 'line'
        , data: {
            labels: donnees.label,
            datasets: [{
                label: 'Température (°C)',
                data: donnees.data,
                backgroundColor: donnees.couleur,
                borderColor: donnees.couleur,
                borderWidth: bordure
            }]
        }
        , options: {
            scales: {
                    y: {
                        min: donnees.min-1
                        //,max: donnees.max-(-1)
                }
            }
            ,responsive: true
            ,maintainAspectRatio: false
        }
    });
    setTimeout(function(){ updateGraph(myChart); }, frequence*1000);
}
function updateGraph(graph){
    var rq = new XMLHttpRequest();
    rq.open("GET", "./get_graph.php?update&f="+frequence);
    rq.onload = function(){
        if(this.readyState === 4){
            try{ var rep = JSON.parse(this.response); }
            catch(e){
                var rep = {erreur:["Erreur de retour sur l'update, le script ne renvoie pas un objet JSON parsable.\n\nRetour du script :\n"+this.response]};
            }

            if(rep.erreur===undefined){
                if(rep.graph.data>0 && rep.graph.label!=null){
                    const couleur = (rep.graph.couleur==null || rep.graph.couleur==undefined)?"#000":rep.graph.couleur;
                    updateData(graph, rep.graph.label, couleur, rep.graph.data)
                    setTimeout(function(){ updateGraph(graph); }, frequence*1000);
                }
                else{
                    console.log("La mise à jour du graphique a échouée");
                    graph.innerHTML += "<p>La mise à jour du graphique a échouée</p>";
                }
            }
            else{
                const nbErr = rep.erreur.length;
                const ligneErreur="retour d'erreur"+((nbErr>1)?"s":"")+" sur l'update du graphique.";
                console.log(ligneErreur);
                graph.innerHTML = ligneErreur;
                for(var i=0; i<nbErr; i++){
                    console.log(rep.erreur[i]);
                    graph.innerHTML += "<br/>"+rep.erreur[i];
                }
            }
        }
    }
    rq.send();
}
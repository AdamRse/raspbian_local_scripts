var bt = document.getElementById("switch_Lampe");
var stat = document.getElementById("status");
var bd = document.querySelector("body");
get_status()
function switchLampe(gpio){
    var rq = new XMLHttpRequest();
    rq.open("GET", "./switch.php?"+gpio);
    rq.onload = function(){
        if(this.readyState === 4){
            if(this.response==1){
                get_status();
            }
            else{
                stat.innerHTML = "Une erreur s'est produite : "+this.response;
            }
        }
    }
    rq.send();
};

function get_status(){
    var rq = new XMLHttpRequest();
    rq.open("GET", "./status.php");
    rq.onload = function(){
        if(this.readyState === 4){
            set_status(this.response);
        }
    }
    rq.send();
}
function set_status(val){
    console.log(val);
    if(val==0){
        stat.innerHTML = "Lampe éteinte";
        bd.style.backgroundColor="#000";
        bd.style.color="#ffc";
    }
    else if(val==1){
        stat.innerHTML = "Lampe allumée";
        bd.style.backgroundColor="#ccc";
        bd.style.color="#440";
    }
    else
        console.log("Erreur de valeur status : ", val);
}

function clicBascule(ordre = 0){
    var rq = new XMLHttpRequest();
    rq.open("GET", "./skip.php?o="+ordre);
    rq.onload = function(){
        if(this.readyState === 4){
            if(this.response==1){
                activeDiodes(ordre);
            }
            else{
                alert("Le script de skip retourne une erreur.\n"+this.response);
            }
        }
    }
    rq.send();
}

function activeDiodes(idActif){
    var bt0=document.getElementById("bt0");
    var bt1=document.getElementById("bt1");
    var bt2=document.getElementById("bt2");
    var stat = document.getElementById("statusSkip");
    if(idActif==1){
        bt0.classList.add("vert-stop");
        bt0.classList.remove("vert-run");
        bt1.classList.add("orange-run");
        bt1.classList.remove("orange-stop");
        bt2.classList.remove("rouge-run");
        bt2.classList.add("rouge-stop");
        stat.innerHTML="Le prochain baculement sera ignoré.";
    }
    else if(idActif==2){
        bt0.classList.add("vert-stop");
        bt0.classList.remove("vert-run");
        bt1.classList.remove("orange-run");
        bt1.classList.add("orange-stop");
        bt2.classList.add("rouge-run");
        bt2.classList.remove("rouge-stop");
        stat.innerHTML="Basculement automatique désactivé.";
    }
    else{
        bt0.classList.remove("vert-stop");
        bt0.classList.add("vert-run");
        bt1.classList.remove("orange-run");
        bt1.classList.add("orange-stop");
        bt2.classList.remove("rouge-run");
        bt2.classList.add("rouge-stop");
        stat.innerHTML="Basculement automatique activé.";
    }
}
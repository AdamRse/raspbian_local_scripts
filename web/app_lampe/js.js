let bt = document.getElementById("switch_Lampe");
let stat = document.getElementById("status");
let bd = document.querySelector("body");
let data = document.getElementById("data");
let requete_bdd = document.getElementById("requete_bdd");

let bt_marche = document.getElementById("bt-marche");
let bt_lever = document.getElementById("bt-skip-lever");
let bt_coucher = document.getElementById("bt-skip-coucher");
let bt_suspend = document.getElementById("bt-suspend");

let tb_lever = bt_lever.querySelector("input");
let tb_coucher = bt_coucher.querySelector("input");

get_status();

tb_lever.addEventListener("focusout", send_skip);
tb_coucher.addEventListener("focusout", send_skip);
tb_lever.addEventListener("keydown", send_skip_keydown);
tb_coucher.addEventListener("keydown", send_skip_keydown);

function send_skip_keydown(event) {
    if (event.key === "Enter") {
        event.preventDefault();
        console.log("Entrée détectée");
        send_skip(event);
        event.target.blur();
    }
}

function send_skip(event) {
    let tb = event.target;
    const regex = /^(\d|[1-4]\d|50)$/;

    if (!tb.dataset.champ_bdd || tb.value == tb.dataset.default_val)
        return false;
    if (!regex.test(tb.value)) {
        display_msg(
            "La valeur SKIP envoyée doit être un entier positif entre 0 et 50",
        );
        tb.value = tb.dataset.default_val;
        return false;
    }

    console.log("La diode demmande l'envoi de " + tb.value, tb);
    verouiller_toutes_diodes();
    if (tb.dataset.champ_bdd == "lampe_run_skip_allumage")
        requete_bdd.dataset.skip_allumage = tb.value;
    else if (tb.dataset.champ_bdd == "lampe_run_skip_arret")
        requete_bdd.dataset.skip_arret = tb.value;
    let rq = new XMLHttpRequest();
    rq.open("GET", "./request.php?" + tb.dataset.champ_bdd + "=" + tb.value);
    rq.onload = function () {
        deverouiller_toutes_diodes();
        if (this.readyState === 4) {
            if (this.response == 1) {
                tb.dataset.default_val = tb.value;
                update_data();
                update_success_diode();
            } else {
                display_msg("Une erreur s'est produite : " + this.response);
            }
        }
    };
    rq.send();
}

function display_msg(text) {
    console.log(text);
    stat.innerHTML = text;
}

function switchLampe(gpio) {
    let rq = new XMLHttpRequest();
    rq.open("GET", "./switch.php?" + gpio);
    rq.onload = function () {
        if (this.readyState === 4) {
            if (this.response == 1) {
                get_status();
            } else {
                display_msg("Une erreur s'est produite : " + this.response);
            }
        }
    };
    rq.send();
}

function get_status() {
    let rq = new XMLHttpRequest();
    rq.open("GET", "./status.php");
    rq.onload = function () {
        if (this.readyState === 4) {
            set_status(this.response);
        }
    };
    rq.send();
}
function set_status(val) {
    if (val == 0) {
        stat.innerHTML = "Lampe éteinte";
        bd.style.backgroundColor = "#000";
        bd.style.color = "#ffc";
    } else if (val == 1) {
        stat.innerHTML = "Lampe allumée";
        bd.style.backgroundColor = "#ccc";
        bd.style.color = "#440";
    } else console.log("Erreur de valeur status : ", val);
}

function clic_diode(diode) {
    let request = get_request_from_diode(diode);
    if (request !== false) {
        verouiller_toutes_diodes();
        let rq = new XMLHttpRequest();
        rq.open("GET", "./request.php?" + request);
        rq.onload = function () {
            if (this.readyState === 4) {
                deverouiller_toutes_diodes();
                if (this.response == 1) {
                    update_data();
                    update_success_diode();
                } else {
                    display_msg(
                        "Le script request.php retourne une erreur :<br/>" +
                            this.response,
                    );
                }
            }
        };
        rq.send();
    }
}

// Ici on calcule l'action à renvoyer pour le script ./ordre.php
// return int|false
function get_request_from_diode(button) {
    if (button === bt_marche) {
        if (data.dataset.suspend == 0) return false;
        else {
            requete_bdd.dataset.suspend = 0;
            return "lampe_run_suspend=0";
        }
    } else if (button === bt_lever) {
        // On n'envoie pas avec un clic, on enverra avec onchange, on sélectionne juste l'input à saisir
        let tb = button.querySelector("input");
        tb.select();
        tb.focus();
        return false;
    } else if (button === bt_coucher) {
        // On n'envoie pas avec un clic, on enverra avec onchange, on sélectionne juste l'input à saisir
        let tb = button.querySelector("input");
        tb.select();
        tb.focus();
        return false;
    } else if (button === bt_suspend) {
        if (data.dataset.suspend == 1) return false;
        else {
            requete_bdd.dataset.suspend = 1;
            return "lampe_run_suspend=1";
        }
    }
}

function update_success_diode() {
    if (data.dataset.suspend == 0) {
        allumer(bt_marche);
        eteindre(bt_suspend);
    } else {
        allumer(bt_suspend);
        eteindre(bt_marche);
    }
    if (data.dataset.skip_allumage > 0) {
        allumer(bt_lever);
    } else {
        eteindre(bt_lever);
    }
    if (data.dataset.skip_arret > 0) {
        allumer(bt_coucher);
    } else {
        eteindre(bt_coucher);
    }
}

function update_data() {
    data.dataset.decallage = requete_bdd.dataset.decallage;
    data.dataset.skip_allumage = requete_bdd.dataset.skip_allumage;
    data.dataset.skip_arret = requete_bdd.dataset.skip_arret;
    data.dataset.suspend = requete_bdd.dataset.suspend;
}
function allumer(diode) {
    if (diode === bt_marche) {
        diode.classList.add("vert-run");
        diode.classList.remove("vert-stop");
    } else if (diode === bt_lever || diode === bt_coucher) {
        diode.classList.add("orange-run");
        diode.classList.remove("orange-stop");
    } else if (diode === bt_suspend) {
        diode.classList.add("rouge-run");
        diode.classList.remove("rouge-stop");
    } else console.log("allumer() : diode inconnue passée en paramètre", diode);
}
function eteindre(diode) {
    if (diode === bt_marche) {
        diode.classList.add("vert-stop");
        diode.classList.remove("vert-run");
    } else if (diode === bt_lever || diode === bt_coucher) {
        diode.classList.add("orange-stop");
        diode.classList.remove("orange-run");
    } else if (diode === bt_suspend) {
        diode.classList.add("rouge-stop");
        diode.classList.remove("rouge-run");
    } else console.log("allumer() : diode inconnue passée en paramètre", diode);
}

function verouiller_toutes_diodes() {
    let all_diodes = document.querySelectorAll("#bt_dashboard div.diode");
    all_diodes.forEach((diode) => verouiller_diode(diode));
}
function deverouiller_toutes_diodes() {
    let all_diodes = document.querySelectorAll("#bt_dashboard div.diode");
    all_diodes.forEach((diode) => deverouiller_diode(diode));
}
function verouiller_diode(diode) {
    //console.log("Verouillage de la diode " + diode.id, diode);
}
function deverouiller_diode(diode) {
    //console.log("Déverouillage de la diode " + diode.id, diode);
}

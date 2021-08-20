var map = L.map('mapid').setView([48.50, 2.29], 4);

var getJSON = function(url, callback) {
    var xhr = new XMLHttpRequest();
    xhr.open('GET', url, true);
    xhr.responseType = 'json';
    xhr.onload = function() {
      var status = xhr.status;
      if (status === 200) {
        callback(null, xhr.response);
      } else {
        callback(status, xhr.response);
      }
    };
    xhr.send();
};

function showCoiffeursGeoJSON(data) {
    var filter_name = document.getElementById('filter_name').value;
    var filter_ville = document.getElementById('filter_ville').value;
    var filter_dept = document.getElementById('filter_dept');
    var dept = filter_dept.options[filter_dept.selectedIndex].text;
    var liste = document.getElementById('listecoiffeurs');
    // Remove all list elements
    while (liste.firstChild) {
        liste.firstChild.remove();
    }
    // Remove all non-tile layers
    map.eachLayer(function (layer) {
        if (! layer.hasOwnProperty('_url') ){
            map.removeLayer(layer);
        }
    });

    var geoJsonLayer = L.geoJSON(data, {
        onEachFeature: function (feature, layer) {
            layer.bindPopup(feature.properties.markerinnerhtml);
        },
        filter: function(feature, layer) {
            var nom = feature.properties.nom;
            var num = feature.properties.num;
            var voie = feature.properties.voie;
            var ville = feature.properties.ville;
            var codepostal = feature.properties.codepostal;
            var addresse = feature.properties.addresse;
            var lat = feature.properties.lat;
            var lng = feature.properties.lng;
            var html = feature.properties.liinnerhtml;
            var li = document.createElement("li");

            if (lat && lng) {
                li.onclick = function() {
                    map.setView([lat, lng], 20);
                };
            }
            li.innerHTML = html;
            if (filter_name == "") {
                if (dept == "*") {
                    if (filter_ville == "") {
                        liste.appendChild(li);
                        return true
                    }
                    if (ville.toLowerCase().includes(filter_ville.toLowerCase())){
                        liste.appendChild(li);
                        return true
                    }
                }
                if (codepostal.startsWith(dept)) {
                    if (filter_ville == "") {
                        liste.appendChild(li);
                        return true
                    }
                    if (ville.toLowerCase().includes(filter_ville.toLowerCase())){
                        liste.appendChild(li);
                        return true
                    }
                }
            }
            if (nom.toLowerCase().includes(filter_name.toLowerCase())) {
                if (dept == "*") {
                    if (filter_ville == "") {
                        liste.appendChild(li);
                        return true
                    }
                    if (ville.toLowerCase().includes(filter_ville.toLowerCase())){
                        liste.appendChild(li);
                        return true
                    }
                }
                if (codepostal.startsWith(dept)) {
                    if (filter_ville == "") {
                        liste.appendChild(li);
                        return true
                    }
                    if (ville.toLowerCase().includes(filter_ville.toLowerCase())){
                        liste.appendChild(li);
                        return true
                    }
                }
            }
            return false
        }
    });
    var markers = L.markerClusterGroup();
    markers.addLayer(geoJsonLayer);
    map.addLayer(markers);
};

L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png?{foo}', {foo: 'bar', attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'}).addTo(map);

var coiffeurs_json; 
getJSON("/coiffeurs.json", function(err, data) {
    if (err !== null) {
        console.log('Something went wrong: ' + err);
    } else {
        coiffeurs_json = data["data"];
        showCoiffeursGeoJSON(coiffeurs_json);
    }
});

Array.from(document.getElementsByClassName("filter")).forEach(input => input.addEventListener('input', function(e){showCoiffeursGeoJSON(coiffeurs_json)}));

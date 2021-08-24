var map = L.map('mapid').setView([48.50, 2.29], 4);
var legend = L.control({position: 'bottomleft'});

legend.onAdd = function (map) {
    var div = L.DomUtil.create('div', 'info legend');
    div.innerHTML+="<p>Cliquez sur le marqueur pour un lien Google Maps</p>";
    return div;
}
legend.addTo(map);
var deptmap = L.map('deptmap').setView([48.50, 2.29], 6);

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

function getDeptColor(blag) {
    if (blag < 2)
        return "#fff7ec";
    if (blag < 3)
        return "#fee8c8";
    if (blag < 4)
        return "#fdd49e";
    if (blag < 5)
        return "#fdbb84";
    if (blag < 6)
        return "#fc8d59";
    if (blag < 7)
        return "#ef6548";
    if (blag < 8)
        return "#d7301f";
    return "#990000";
}

function showDeptGeoJSON(data) {
    L.geoJSON(data, {
        onEachFeature: function (feature, layer) {
            var htmll = "<p>"+feature.properties.nom+": "+feature.properties.blagueurs+" de blagues";
            layer.bindPopup(htmll);
        },
        style: function(feature) {
            var blag = parseFloat(feature.properties.blagueurs);
            return {
                fillColor: getDeptColor(blag),
                weight: 2,
                color: "#EEEEEE",
                fillOpacity: 0.7
            };

        }
    }).addTo(deptmap);

    var legend = L.control({position: 'bottomright'});

	legend.onAdd = function (map) {
		var div = L.DomUtil.create('div', 'info legend'),
			grades = [2, 3, 4, 5, 6, 7, 8, 9];
			labels = [];

		div.innerHTML+="<p>Pourcentage de blagueurs</p>"
		// loop through our density intervals and generate a label with a colored square for each interval
		for (var i = 0; i < grades.length; i++) {
			div.innerHTML +=
				'<i style="background:' + getDeptColor(grades[i] + 1) + '"></i> ' +
				grades[i] + (grades[i + 1] ? '&ndash;' + grades[i + 1] + '<br>' : '+');
		}
		return div;
	};

	legend.addTo(deptmap);
}


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
    var counter = document.getElementById("resultcount");
    markers.addLayer(geoJsonLayer);
    counter.innerHTML="Nb de résultats: "+markers.getLayers().length;
    map.addLayer(markers);
};

L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png?{foo}', {foo: 'bar', attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'}).addTo(map);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png?{foo}', {foo: 'bar', attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'}).addTo(deptmap);

var coiffeurs_json; 
getJSON("/coiffeurs.json", function(err, data) {
    if (err !== null) {
        console.log('Something went wrong: ' + err);
    } else {
        coiffeurs_json = data["data"];
        showCoiffeursGeoJSON(coiffeurs_json);
    }
});

getJSON("/departements.geojson", function(err, data) {
    if (err !== null) {
        console.log('Something went wrong: ' + err);
    } else {
        showDeptGeoJSON(data);
    }
});


Array.from(document.getElementsByClassName("filter")).forEach(input => input.addEventListener('input', function(e){showCoiffeursGeoJSON(coiffeurs_json)}));

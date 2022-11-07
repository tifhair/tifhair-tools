var map = L.map('mapid', {
    zoomControl: false
});
map.setView([48.50, 2.29], 4);
map.attributionControl.setPosition('topright');
var legend = L.control({position: 'bottomleft'});

var gradients = [
    "#fac569",
    "#f8ba61",
    "#f5ae5a",
    "#f2a353",
    "#ef974b",
    "#eb8c44",
    "#e8803d",
    "#e47436",
    "#e0672f",
    "#dc5a28",
    "#d74c21",
    "#d33d1a",
    "#ce2b14",
    "#c90d0d",
    "#d90d0d",
];


legend.onAdd = function (map) {
    var div = L.DomUtil.create('div', 'info legend');
    div.innerHTML+="<p>Cliquez sur un marqueur pour voir la devanture sur Google Maps</p>";
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
   if (blag < 3)
       return gradients[0];
   if (blag < 4)
       return gradients[1];
   if (blag < 5)
       return gradients[2];
   if (blag < 6)
       return gradients[3];
   if (blag < 7)
       return gradients[4];
   if (blag < 8)
       return gradients[5];
   if (blag < 9)
       return gradients[6];
   if (blag < 10)
       return gradients[7];
   if (blag < 11)
       return gradients[8];
   if (blag < 12)
       return gradients[9];
   if (blag < 13)
       return gradients[10];
  if (blag < 14)
       return gradients[11];
   if (blag < 15)
       return gradients[12];
   if (blag < 16)
       return gradients[13];
   if (blag < 17)
       return gradients[13];
   return gradients[-1];
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
			grades = [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];
			labels = [];

		div.innerHTML+="<p>Pourcentage de blagueurs</p>"
		// loop through our density intervals and generate a label with a colored square for each interval
		for (var i = 0; i < grades.length; i++) {
			div.innerHTML +=
				'<i style="background:' + gradients[i] + '"></i> ' +
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
            if (codepostal == null) {
                // fucking Aniere
                return false
            }

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
            if (nom.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z]/g,"").includes(filter_name.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z]/g,""))) {
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

# Les coiffeurs sont des blagueurs

Outils utilisés pour générer le site [Tif'Hair](https://tif.hair).

## Dependances

`apt install ruby ruby-geocoder ruby-progressbar`


## Utilisation

Télécherger les deux fichiers [StockEtablissement_utf8.zip](https://files.data.gouv.fr/insee-sirene/StockEtablissement_utf8.zip) et [StockUniteLegale_utf8.zip](https://files.data.gouv.fr/insee-sirene/StockUniteLegale_utf8.zip), qui se trouvent sur [https://www.data.gouv.fr/en/datasets/base-sirene-des-entreprises-et-de-leurs-etablissements-siren-siret/](https://www.data.gouv.fr/en/datasets/base-sirene-des-entreprises-et-de-leurs-etablissements-siren-siret/) 

Une fois décompressés, faire une première passe pour filtrer les lignes interessantes:

```
{ head -n 1 StockEtablissement_utf8.csv  & grep "96.02A" StockEtablissement_utf8.csv ; } > SE.csv
{ head -n 1 StockUniteLegale_utf8.csv  & grep "96.02A" StockUniteLegale_utf8.csv ; } > SUL.csv

```

lancer l'extraction (c'est long, la lib CSV de ruby n'est pas des plus efficaces, normalement moins d'une heure):

```
ruby sirene.rb /tmp/SE.csv /tmp/SUL.csv /tmp/coiffeurs.sqlite
```

Puis faire une passe de résolution adresse => coordonnées GPS (qui prendra probablement encore environ 1h):

```
ruby tools/coords.rb coiffeurs.sqlite
```

Si vous possédez une clé API qui permet d'accéder aux API géocoding de Google, vous pouvez refaire une passe pour combler les trous:

```
echo "IPhOPOhp_HHhhhO_9ihiuHoihOHIIHhOOIhIOihu" > .api_key
ruby tools/coords.rb coiffeurs.sqlite .api_key
```

Ensuite il faut indiquer quels noms sont "droles":
```
ruby tools/blague.rb coiffeurs.sqlite 
```

Le script marquera certains "classiques" comme "droles", mais pour la grande majorité, il faudra indiquer si le nom est comique (en appuyant sur entrée) ou non (en appuyant sur qq touches au pif + entrée)

Puis, parceque de nombreux doublons peuvent exister (Plusieurs enseignes aux mêmes coordonnées GPS) pour plusieurs raisons:
  * Changement de SIRET pour un établissement, mais conservation d'un nom rigolo
  * Plusieurs noms rigolos enregistrés pour un établissement
  * etc.
il faut également lancer un script qui vous demandera de choisir quel nom afficher en cas de double:

```
ruby tools/main.rb coiffeurs.sqlite
```

Exemple de doublon:
```
[0]RECRE A TIFS(39888921200013), [1]BELL'HAIR COIFFURE(53227002200017)	http://www.google.com/maps/place/49.125478,-0.209758
```

Accéder au lien Google Maps pour voir la deventure montre qu'il s'agit bien d'un "BELL'HAIR".

Une passe supplémentaire qui tentera de détecter des anomalies (par exemple des coordonnées GPS hors de la zone d'un département)

```
ruby tools/anomalies.rb coiffeurs.sqlite
```

Générez ensuite le site dans le répertoire `build` avec:

```
ruby tools/statify.rb src build
```


### Mettre à jour une base existante

Récupérez les fichiers `SE.csv` et `SUL.csv` comme précédemment, pour générer une nouvelle base coiffeurs.sqlite avec le script `sirene.rb`.

Puis l'outil suivant va d'abord faire un backup de `old_coiffeurs.sqlite` pour ensuite y ajouter les éléments de la nouvelle base, puis demander si les nouveaux noms trouvés sont drôles ou pas.

```
ruby tools compare.rb <old_coiffeurs.sqlite> <new_coiffeurs.sqlite>
```

Puis faire une passe de résolution adresse => coordonnées GPS, et déduplication:

```
ruby tools/coords.rb coiffeurs.sqlite
ruby tools/main.rb coiffeurs.sqlite
ruby tools/anomalies.rb coiffeurs.sqlite
```

## Contactez moi

Un email, à une adresse qui commencerait par 'contact', avec un @ au milieu, et finirait par le nom du site web. En revanche, si vous espérez une réponse de ma part, un DM Twitter sur @tif_hair ou une issue ouverte ici auront plus de succès.

Ou ouvrez une issue sur Github :)

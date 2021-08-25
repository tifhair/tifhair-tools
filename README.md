# Les coiffeurs sont des blagueurs

Outils utilisés pour générer le site [Tif'Hair](https://tif.hair).

## Dependances

`apt install ruby ruby-geocoder ruby-progressbar`


## Utilisation

Télécherger les deux fichiers [StockEtablissement_utf8.zip](https://files.data.gouv.fr/insee-sirene/StockEtablissement_utf8.zip) et [StockUniteLegale_utf8.zip](https://files.data.gouv.fr/insee-sirene/StockUniteLegale_utf8.zip), qui se trouvent sur [https://www.data.gouv.fr/en/datasets/base-sirene-des-entreprises-et-de-leurs-etablissements-siren-siret/](https://www.data.gouv.fr/en/datasets/base-sirene-des-entreprises-et-de-leurs-etablissements-siren-siret/) 

Une fois décompressés, lancer l'extraction (c'est long, la lib CSV de ruby n'est pas des plus efficaces, normalement moins d'une heure):

```
{ head -n1 StockEtablissement_utf8.csv & grep 96.02A StockEtablissement_utf8.csv; } > coiffeurs.csv
ruby tools/sirene.rb coiffeurs.csv StockUniteLegale_utf8.csv
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

Générez ensuite le site dans le répertoire `build` avec:

```
ruby tools/statify.rb src build
```

## Contactez moi

Ouvrez une issue sur Github :)

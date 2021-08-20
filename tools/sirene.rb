require "csv"
require "sqlite3"

STDOUT.sync = true

dbfile = "coiffeurs.sqlite"
db = SQLite3::Database.open(dbfile)

if not File.exist?(dbfile)
  db.transaction
  db.execute "CREATE TABLE Coiffeurs(siret TEXT UNIQUE PRIMARY KEY, siren TEXT, name TEXT, date DATE, codepostal TEXT, active BOOL, ville text, numero_rue text, voie text, lat FLOAT, lng FLOAT, global_code TEXT, blague BOOL, etat TEXT);"
  db.commit
end

def usage()
  puts "run sirene.rb StockEtablissement_utf8.csv StockUniteLegale_utf8.csv"
end

etab_file = ARGV[0]
unless File.exist?(etab_file)
  usage
  exit
end

unite_file = ARGV[1]
unless File.exist?(unite_file)
  usage
  exit
end


# Load extra possible names 
extra_names = {}
CSV.foreach(ARGV[0], headers:true) do |l|
  next if l['activitePrincipaleUniteLegale'] != "96.02A"
  nom = l['denominationUsuelle1UniteLegale'] || l['denominationUsuelle2UniteLegale'] || l['denominationUsuelle3UniteLegale']
  next unless nom
  siren = l['siren']
  extra_names[siren] = nom
end

total = `wc -l /tmp/StockEtablissement_utf8.csv  | cut -d " " -f 1`.strip().to_i()

i = 0
CSV.foreach('/tmp/StockEtablissement_utf8.csv', headers:true) do |line|
  i+=1
  if i%50000 == 0
    $stderr.puts "\r #{i}/#{total} (#{100*i/total}%)\r"
  end
  activite = line["activitePrincipaleEtablissement"]
  next unless activite
  next unless activite.start_with?("96.02A")
  name = (line["enseigne1Etablissement"] || "").strip
  if name == ""
    name = extra_names[siren[0..8]] 
  end
  next unless name
  siret = line["siret"]
  codepostal = line["codePostalEtablissement"]
  date_creation = line["dateCreationEtablissement"]
  ville = line['libelleCommuneEtablissement']
  numero_rue, = line['numeroVoieEtablissement']
  type = line['typeVoieEtablissement']
  rue = line['libelleVoieEtablissement']
  etat = line['etatAdministratifEtablissement']
  db.execute("INSERT INTO Coiffeurs (siret, siren, name, date, codepostal, active, ville, numero_rue, voie) VALUES (?,?,?,?,?,?,?,?,?,?)",
            siret,
            siret[0..8],
            name,
            date_creation,
            codepostal,
            0,
            ville,
            numero_rue,
            [type, rue].join(' ').strip(),
            etat
            )
end


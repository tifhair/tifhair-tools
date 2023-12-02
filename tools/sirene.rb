require "csv"
require "sqlite3"
require "progressbar"
require "set"

STDOUT.sync = true
$debug=false

def usage()
  puts "ruby sirene.rb StockEtablissement_utf8.csv StockUniteLegale_utf8.csv coiffeurs.sqlite <code_naf> <table name>"
  exit 1
end

etab_file = ARGV[0]
if not etab_file or not File.exist?(etab_file)
  puts "Impossible de trouver le fichier des Établissements #{etab_file}"
  usage
end

unite_file = ARGV[1]
if not unite_file or not File.exist?(unite_file)
  puts "Impossible de trouver le fichier des Unités légales #{unite_file}"
  usage
end

dbfile = ARGV[2]
if not dbfile
  puts "Merci de fournir un fichiers de destination"
  usage
end

code_naf = ARGV[3]
if not code_naf
  code_naf = "96.02A"
end

table_name = ARGV[4]
if not table_name
  table_name = "Coiffeurs"
end


if File.exist?(dbfile)
  puts "Le fichier #{dbfile} existe déjà..."
  exit 1
end

if not File.exist?(dbfile)
  db = SQLite3::Database.open(dbfile)
  db.transaction
  puts "CREATE TABLE #{table_name} (siret TEXT UNIQUE PRIMARY KEY, siren TEXT, name TEXT, date TEXT, codepostal TEXT, active INTEGER, ville text, numero_rue text, voie text, lat REAL, lng REAL, global_code TEXT, etat TEXT) STRICT;"
  db.execute "CREATE TABLE #{table_name} (siret TEXT UNIQUE PRIMARY KEY, siren TEXT, name TEXT, date TEXT, codepostal TEXT, active INTEGER, ville text, numero_rue text, voie text, lat REAL, lng REAL, global_code TEXT, etat TEXT) STRICT;"
  db.execute "CREATE TABLE Names(id INTEGER PRIMARY KEY, siret TEXT, name TEXT, blague INTEGER, seen INTEGER DEFAULT 0, main INTEGER DEFAULT 1, commentaire TEXT, UNIQUE(siret, name)) STRICT;"
  db.commit
  db.close()
end

db = SQLite3::Database.open(dbfile)
db.synchronous = 0
db.journal_mode = 'memory'

$stderr.puts "Loading extra possible names from #{unite_file} 1/2"
$stderr.puts "calculating number of lines to parse"
total = `wc -l "#{unite_file}"  | cut -d " " -f 1`.strip().to_i()
progressbar = ProgressBar.create(total: total, format: '%a %e %P% Processed: %c from %C')
extra_names = {}
i=0
CSV.foreach(unite_file, headers:true) do |l|
  i+=1
  begin
    progressbar.progress += 10000 if i%10000 ==0
  rescue
  end

  case l['statutDiffusionUniteLegale']
  when 'O'
  when 'P'
    next
  else
    raise "Unexpected statutDiffusionUniteLegale: #{l['statutDiffusionUniteLegale']}"
  end
  next if l['activitePrincipaleUniteLegale'] != code_naf
  noms = [l['denominationUniteLegale'],  l['denominationUsuelle1UniteLegale'], l['denominationUsuelle2UniteLegale'], l['denominationUsuelle3UniteLegale']]
  siren = l['siren']
  extra_names[siren] = noms
end
progressbar.finish

$stderr.puts "Loading main SIRENE database from from #{etab_file} 2/2"
$stderr.puts "calculating number of lines to parse"
total = `wc -l "#{etab_file}"  | cut -d " " -f 1`.strip().to_i()
progressbar = ProgressBar.create(total: total, format: '%a %e %P% Processed: %c from %C')
nb_inserted = 0
CSV.foreach(etab_file, headers:true) do |line|
  i+=1
  begin
    progressbar.progress += 100 if i%100 ==0
  rescue
  end
  activite = line["activitePrincipaleEtablissement"]
  next unless activite
  next unless activite.start_with?(code_naf)
  names = [line["enseigne1Etablissement"], line["enseigne2Etablissement"], line["enseigne3Etablissement"], line["denominationUsuelleEtablissement"]].compact
  siret = line["siret"]
  extras = extra_names[siret[0..8]]
  names = names.concat(extras).compact if extras
  names = Set.new(names).to_a
  next if names.size == 0
  codepostal = line["codePostalEtablissement"]
  date_creation = line["dateCreationEtablissement"]
  ville = line['libelleCommuneEtablissement']
  numero_rue, = line['numeroVoieEtablissement']
  type = line['typeVoieEtablissement']
  rue = line['libelleVoieEtablissement']
  etat = line['etatAdministratifEtablissement']
  db.transaction do |trans|
    trans.execute("INSERT INTO #{table_name} (siret, siren, date, codepostal, ville, numero_rue, voie, etat) VALUES (?,?,?,?,?,?,?,?)",
              siret,
              siret[0..8],
              date_creation,
              codepostal,
              ville,
              numero_rue,
              [type, rue].join(' ').strip(),
              etat,
              )
    names.each do |nom|
      trans.execute("INSERT INTO names (id, siret, name, blague, main) VALUES (NULL, ?, ?, NULL, 1)", siret, nom)
      nb_inserted+=1
    end
  end
end

progressbar.finish

if nb_inserted == 0
  raise Exception.new("No name added from #{etab_file} ????")
end

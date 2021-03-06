require "uri"
require "fileutils"
require "json"
require "slim"
require 'slim/include'
require "sqlite3"

Slim::Engine.set_options pretty: true, sort_attrs: false


def usage
  puts "run statify.rb <source_dir> <dest_dir>"
end

source_dir = ARGV[0]
dest_dir = ARGV[1]

if not source_dir or not File.exist?(source_dir)
  usage
  exit
end

if not dest_dir
  usage
  exit
end

if not File.directory?(dest_dir)
  puts "#{dest_dir} does not exist"
  exit
end

def db_get_addresse_by_name(db, name)
  rows = db.execute("SELECT n.name, c.numero_rue, c.voie, c.ville  FROM Coiffeurs as c, Names as n WHERE n.name = ? AND etat='A' AND n.siret=c.siret ORDER BY RANDOM() LIMIT 1", name)
  if rows.size==1
    _, num, voie, ville = rows[0]
    addresse = [num, voie, ville].join(' ').strip()
    return addresse
  end
  return ""
end

def percent_pays(db_file)
  db = SQLite3::Database.open(db_file)
  nb_blagues = db.execute("select count(DISTINCT(c.siret)) from coiffeurs as c, names as n where c.siret = n.siret  and n.blague=1 and c.etat='A'")[0][0].to_i
  nb_coiffeurs = db.execute("select count(DISTINCT(c.siret)) from coiffeurs as c where c.etat='A'")[0][0].to_i
  return 100.0*nb_blagues/nb_coiffeurs
end


def make_json(db_file, dest_dir)
  db = SQLite3::Database.open(db_file)
  res = {'data' => {
    "type"=>"FeatureCollection",
    "name" => "Coiffeurs Blagueurs",
    "features" => []}}
  db.execute("SELECT n.name, c.lat, c.lng, c.numero_rue, c.voie, c.ville, c.codepostal  FROM Coiffeurs as c, Names as n WHERE etat = 'A' AND blague=1 AND n.siret=c.siret AND n.main=1 ORDER BY RANDOM()").each do |row|
    nom,lat,lng,num, voie,ville, codepostal = row
    nom = nom.downcase().split.map(&:capitalize).join(' ')
    addresse = [num, voie, ville].join(' ').strip()
    res['data']["features"] << {
      "type" => "Feature",
      "properties"=> {
        "nom"=> nom,
        "lat"=> lat,
        "lng"=> lng,
        "num"=> num,
        "voie"=> voie,
        "ville" => ville,
        "codepostal" => codepostal,
        "markerinnerhtml" => make_marker_html(nom, addresse),
        "liinnerhtml" => "<b>#{nom}</b><span>, #{ville} (#{codepostal})</span>",
        "addresse"=> addresse
      },
      "geometry"=> {
        "type"=> "Point",
        "coordinates"=> [lng, lat] }
    }
  end

  json_path = File.join(dest_dir, "coiffeurs.json")
  File.open(json_path, 'w') do |f|
    f.write(res.to_json)
  end
  puts "Written #{json_path}"
end

def gmap_url(nom, addresse)
  n = URI.encode_www_form_component(nom)
  a = URI.encode_www_form_component(addresse)
  return "https://www.google.com/maps/?q=#{n} #{a}"
end

def make_marker_html(nom, addresse)
  return "<p><b>#{nom}</b></p><p><a class='button' target='_blank' href='#{gmap_url(nom, addresse)}'>Voir la devanture via Google Maps</a></p>"
end

def slimify(slim_template, dest, params=nil)
  File.open(dest, 'w') do |f|
    content = Slim::Template.new(slim_template).render(Object.new, params)
    f.write(content)
  end
  puts "written #{dest}"
end

def copy_dir(source, dest)
  FileUtils.cp_r(source, dest, verbose:true)
end

$cached_dept = nil

def load_dept(db)
  depts = %w{971 972 973 976 01 02 03 04 05 06 2A 2B 07 08 09 10 11 12 13 14 15 16 17 18 19 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 974}
  res = db.execute("SELECT c.codepostal, n.blague FROM Coiffeurs as c, Names as n WHERE etat='A' AND c.siret = n.siret")
  $cached_dept = {}
  res.each do |row|
    next unless row[0]
    cp = row[0]
    dept = cp[0..1]
    if cp.start_with?("97")
      dept = cp[0..2]
    end
    if $cached_dept[dept]
      if row[1] == 1
        $cached_dept[dept][:blague]+=1
      end
      $cached_dept[dept][:total]+=1
    else
      $cached_dept[dept] = {blague: 0,total:1}
      $cached_dept[dept][:blague]+=1 if row[1] == 1
    end
  end
end

def get_coiffeurs_by_dept(db_file, dept)

  d = dept
  if d == "2A"
    d = "20"
  end
  if d== "2B"
    d = "20"
  end

  db = SQLite3::Database.open(db_file)
  if not $cached_dept
    load_dept(db)
  end

  percent = 100.0 * $cached_dept[d][:blague] / $cached_dept[d][:total]
  return percent
end


def make_dept_geojson(db_file, source, dest)
  j = JSON.parse(File.read(source))
  j["features"].each do |f|
    code = f["properties"]["code"]
    percent = get_coiffeurs_by_dept(db_file, code)
    f["properties"]["blagueurs"] = "%0.2f%%" % percent
  end
  File.open(dest, 'w') do |f|
    f.write(j.to_json)
  end
  puts "written #{dest}"
end

def db_get_count_pattern(db, pattern)
  return db.execute("SELECT count(*) from Coiffeurs as c, Names as n WHERE c.etat = 'A' AND n.name LIKE ? AND n.siret=c.siret LIMIT 1", pattern)[0][0]
end

def build_stats(db_file, slim_file)
  db = SQLite3::Database.open(db_file)
  content = <<-SLIM1.chomp
/ Ne pas ??diter ce fichier, le script statify.rb l'??crasera
div class='palmares'
  h3
    | D'abord quelques chiffres:
  ul

SLIM1

[
    ["Imagin'hair",   "%imagin%air%"],
    ["Bulles d'hair", "%bull%d%air%"],
    ["Atmosp'hair",   "%atmos%air%"],
    ["Caract'hair",   "%ara%t%hair%"],
    ["Planet'hair",   "%planet%hair%"],
  ].each do |n,r|
    content <<
"""
    li
      | Il y a 
      strong
"""
    content << "        | #{db_get_count_pattern(db, r)}\n"
    content << "      |  salons actifs avec un nom d??riv?? de \n"
    content << "      strong\n"
    content << "        | #{n}\n"
  end
[
    ["Diminu'tif",   "%diminu%tif%"],
    ["Evolu'tif",    "%evolu%tif%"],
    ["Infini'tif",   "%infini%tif%"],
    ["Imagina'tif",  "%imagi%na%tif%"],
    ["Instinc'tif",  "%instin%tif%"],
  ].each do |n,r|
    content <<
"""
    li
      | On trouve 
      strong
"""
    content << "        | #{db_get_count_pattern(db, r)}\n"
    content << "      |  salons actifs avec un nom similaire ?? \n"
    content << "      strong\n"
    content << "        | #{n}\n"
  end

  content << """
  h3
    | Palmar??s d'excellents calembours
  p
    | Une liste de blagues ?? caract??re animalier:
    ul
"""
  [
    "HAIR'IS'SON",
    "VIP'HAIR",
    "BUTT'HAIR FLY"
  ].each do |n|
    content << "      li\n        a target='_blank' href='#{gmap_url(n, db_get_addresse_by_name(db, n))}'\n         | #{n}\n"
  end

  content << """
  p
    | Des phrases et locutions:
    ul
"""
  [
    "AU PAYS DES M'HAIR VEILLES",
    "AINSI SOIT TIF",
    "AH QUE TIFS",
    "TELLE M'HAIR TELLE FILLE",
    "SAVOIR COIF HAIR",
    "FAUDRA TIF HAIR",
    "LE BEST C L'HAIR",
    "ALT'HAIR  & GO",
    "JENNY PEIGNE NI CISEAUX",
    "COURT TOUJOURS",
    "BOUCLE LA",
    "PAUSE COIFFEE",
    "COUPE DU MONDE",
  ].each do |n|
    content << "      li\n        a target='_blank' href='#{gmap_url(n, db_get_addresse_by_name(db, n))}'\n         | #{n}\n"
  end

  content << """
  p
    | Certains tentent des blagues multi-lingues:
    ul
"""
  [
    "UPSTHAIRS",
    "UNITED HAIR LINES",
    "F'HAIR PLAY",
    "ROCKSTHAIR",
    "ROCK HAIR ROLL",
    "BIO TIFF HOULE",
  ].each do |n|
    content << "      li\n        a target='_blank' href='#{gmap_url(n, db_get_addresse_by_name(db, n))}'\n         | #{n}\n"
  end

  content << """
  p
    | Les fans de math??matiques pourront se rendre au choix chez:
    ul
"""
  [
    "TRIANGUL'HAIR",
    "LINE ET HAIR"
  ].each do |n|
    content << "      li\n        a target='_blank' href='#{gmap_url(n, db_get_addresse_by_name(db, n))}'\n         | #{n}\n"
  end

  content << """
  p
    | Tandis que les litt??raires seront plus attir??s par:
    ul
"""
  [
    "VOLT'HAIR COIFFURE",
    "APAULINE'HAIR",
    "GRAMME HAIR",
  ].each do |n|
    content << "      li\n        a target='_blank' href='#{gmap_url(n, db_get_addresse_by_name(db, n))}'\n         | #{n}\n"
  end

  content << """
  p
    | Les informaticiens ne sont pas en reste avec:
    ul
"""
  [
      "CYB HAIR",
      "CIB'HAIR"
  ].each do |n|
    content << "      li\n        a target='_blank' href='#{gmap_url(n, db_get_addresse_by_name(db, n))}'\n         | #{n}\n"
  end


  content << """
  p
    | De nombreuses possibilit??s pour int??grer son nom dans celui de son salon:
    ul
"""
  [
    "AXELLE' HAIR",
    "VAL'HAIR'IE",
    "JENNIF'HAIR",
    "TIFFANY COIFFURE",
    "HAIR'V",
    "CL' HAIR",
    "EMMAGINA'TIF",
    "BERENG'HAIR",
    "SEV HAIR'IN",
    "FRED'HAIR'IC",
    "ALB'HAIR COIFFURE A DOMICILE",
    "MYLEN HAIR",
    "J'HAIR-AIME",
    "HAIR'ONE",
  ].each do |n|
    content << "      li\n        a target='_blank' href='#{gmap_url(n, db_get_addresse_by_name(db, n))}'\n         | #{n}\n"
  end

  content << """
  p
    | Plusieurs salons ont un nom en rapport avec la r??gion:
    ul
      li
        a target='_blank' href='#{gmap_url("CORS'HAIR", db_get_addresse_by_name(db, "CORS'HAIR"))}'
          | CORS'HAIR
        |  ?? Saint-Malo
      li
        a target='_blank' href='#{gmap_url("FINIST'HAIR", db_get_addresse_by_name(db, "FINIST'HAIR"))}'
          | FINIST'HAIR
        |  en Bretagne
      li
        a target='_blank' href='#{gmap_url("LOZ'HAIR COIFFURE", db_get_addresse_by_name(db, "LOZ'HAIR COIFFURE"))}'
          | LOZ'HAIR COIFFURE
        |  ??videmment, en Loz??re
"""

  content << """
  p
    | Ceux-ci semblent pouvoir fournir des services... 'diff??rents':
    ul
"""
  [
    "CED'A TIF",
    "ADULT'HAIR",
    "MISSION HAIR",
  ].each do |n|
    content << "      li\n        a target='_blank' href='#{gmap_url(n, db_get_addresse_by_name(db, n))}'\n         | #{n}\n"
  end

  content << """
  p
    | Ces salons n'h??sitent pas ?? chercher dans les r??f??rences 'Pop':
    ul
"""
  [
    "ABRARACOUR 'TIFS",
    "BLADE RUNHAIR",
    "TIFS ET TONDU",
    "SPEED'HAIR MAN",
    "PRINCE DE BEL HAIR",
    "PARTOUTA'TIF",
    "GIJHAIR",
    "FACELOOK",
    "TWITT'HAIR"
  ].each do |n|
    content << "      li\n        a target='_blank' href='#{gmap_url(n, db_get_addresse_by_name(db, n))}'\n         | #{n}\n"
  end

  content << """
  p
    | Une s??l??ction de noms tr??s originaux:
    ul
"""
  [
    "LA CHAMBRE A HAIR",
    "VENT'CONTR'HAIR",
    "TRALAL'HAIR",
    "SAGIT HAIR",
    "REVOLVHAIR",
    "RECUP'HAIR",
    "COUPE DU MONDE",
    "NUCL HAIR",
    "LA POUDRI'HAIR",
    "PETARD A MECHE",
    "NEFERTI'TIF",
    "NAMAST'HAIR",
    "LUCIF'HAIR",
    "IMP'HAIRIAL",
    "F'HAIR FORGE-COIFFURE",
    "DIV HAIR GENS",
    "CYMIL'HAIR",
    "COLOCAT'HAIR",
    "CLAFOU'TIFS",
    "BUENO S HAIR",
    "SPACE INVHEADER",
    "BOUC ET MISS HAIR",
  ].each do |n|
    content << "      li\n        a target='_blank' href='#{gmap_url(n, db_get_addresse_by_name(db, n))}'\n         | #{n}\n"
  end

  content << """
  p
    | Certains salons semblent avoir tent?? des jeux de mots, pas tout ?? fait heureux, ou avec le mauvais champs lexical:
    ul
"""
  [
      "ABCD TIF",
      "ARTIST'TIF",
      "SCARAMECHE"
  ].each do |n|
    content << "      li\n        a target='_blank' href='#{gmap_url(n, db_get_addresse_by_name(db, n))}'\n         | #{n}\n"
  end

  content << """
  p
    | En listant les mots utilis??s par chaque ??tablissement, tri?? par ordre d'apparition, et filtr?? sur le champs lexical de la coiffure a ??galement permis de d??terrer quelques perles comme:
    ul
"""
  [
    "NO S TRESSES",
    "QUEER CHEVELU",
    "SAM DECOIFF",
    "LA COUPA CABANA",
    "NO PEIGNE NO GAIN"
  ].each do |n|
    content << "      li\n        a target='_blank' href='#{gmap_url(n, db_get_addresse_by_name(db, n))}'\n         | #{n}\n"
  end

  content << """
  p
    | Mais le plus dr??le de tous reste:
    ul
"""
  [
      "MD'HAIR"
  ].each do |n|
    content << "      li\n        a target='_blank' href='#{gmap_url(n, db_get_addresse_by_name(db, n))}'\n         | #{n}\n"
  end

  content << """
  p
    | Pour finir, il semble que depuis le d??but de l'enregistrement des ??tablissements dans la base de l'INSEE, aucun salon de coiffure ne se soit appel??:
    ul
      li
        | 'Ap??ritif'
      li
        | 'Culin'hair'
      li
        | 'James Blonde'
"""

  File.open(slim_file, 'w') do |f|
    f.write(content)
  end
  puts "written #{slim_file}"
end


db_file = File.join(source_dir, "coiffeurs.sqlite")
puts "making dept geojson"
make_dept_geojson(db_file, File.join(source_dir, "geojson", "departements-avec-outre-mer.geojson" ), File.join(dest_dir, "departements.geojson"))
puts "making geojson"
make_json(db_file, dest_dir)

puts "making stats"
build_stats(db_file, File.join(source_dir, "stats.slim"))

puts "making main.slim"
slimify(File.join(source_dir, "main.slim"), File.join(dest_dir, "index.html"), {percent_pays: percent_pays(db_file)})
copy_dir(File.join(source_dir, 'css' ), dest_dir)
copy_dir(File.join(source_dir, 'js'), dest_dir)
copy_dir(File.join(source_dir, 'pics'), dest_dir)
copy_dir(File.join(source_dir, 'geojson'), dest_dir)

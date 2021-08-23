require "uri"
require "fileutils"
require "json"
require "slim"
require 'slim/include'
require "sqlite3"

Slim::Engine.set_options pretty: true, sort_attrs: false

$blague = 'etat = "A" AND blague=1 ORDER BY RANDOM()'
#$blague = 'etat = "A" AND (name LIKE "%tif%" OR name LIKE "%hair%" OR name LIKE "%epi%" OR name LIKE "%mech%") ORDER BY RANDOM()'

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
  rows = db.execute("SELECT name, numero_rue, voie, ville  FROM Coiffeurs WHERE name = ? AND etat='A' ORDER BY RANDOM() LIMIT 1", name)
  if rows.size==1
    _, num, voie, ville = rows[0]
    addresse = [num, voie, ville].join(' ').strip()
    return addresse
  end
  return ""
end


def make_json(db_file, dest_dir, filter)
  db = SQLite3::Database.open(db_file)
  res = {'data' => {
    "type"=>"FeatureCollection",
    "name" => "Coiffeurs Blagueurs",
    "features" => []}}
  db.execute("SELECT name, lat, lng, numero_rue, voie, ville, codepostal  FROM Coiffeurs WHERE #{filter}").each do |row|
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
        "liinnerhtml" => "<b>#{nom}</b>, #{ville} (#{codepostal})",
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
  return "https://maps.google.com/?q=#{n} #{a}"
end

def make_marker_html(nom, addresse)
  return "<p><b>#{nom}</b></p><p><a class='button' target='_blank' href='#{gmap_url(nom, addresse)}'>Ouvrir dans Google Maps</a></p>"
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

def get_coiffeurs_by_dept(db_file, dept)
  d = dept
  if d == "2A"
    d = "20"
  end
  if d== "2B"
    d = "20"
  end
  db = SQLite3::Database.open(db_file)

  res = db.execute("SELECT count(*) FROM Coiffeurs WHERE codepostal LIKE ? AND #{$blague}", d+"%")
  blagueurs =  res[0][0]
  res = db.execute("SELECT count(*) FROM Coiffeurs WHERE codepostal LIKE ?", d+"%")
  tous  =  res[0][0]
  percent = 100.0 * blagueurs / tous 
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
  return db.execute("SELECT count(*) from Coiffeurs WHERE #{pattern} LIMIT 1")[0][0]
end

def build_stats(db_file, slim_file)
  db = SQLite3::Database.open(db_file)
  content = <<-SLIM1.chomp
/ Ne pas éditer ce fichier, le script statify.rb l'écrasera
div class='palmares'
  h3
    | D'abord quelques chiffres:
  p
    ul

SLIM1
[
    ["caract'hair", "%ara%t%hair%"],
    ["Atmosp'hair",   "%atmos%air%"],
    ["Imagin'hair",   "%imagin%air%"],
    ["Bulles d'hair", "%bull%d%air%"],
    ["caract'hair",   "%ara%t%hair%"],
  ].each do |n,r|
    content << "      li\n        |Il y a #{db_get_count_pattern(db, "etat='A' AND name LIKE '#{r}'")} salons actifs avec un nom dérivé de \"#{n}\"\n"
  end

  content << """
  h3
    | Palmarès d'excellents calembours
  p
    | Bien qu'il ne soit plus en activité, le salon 
    a target='_blank' href='#{gmap_url('A Thaon Tifs', db_get_addresse_by_name(db, 'A Thaon Tifs'))}'
      | A Thaon Tifs
    |  à Thaon (Calvados) réalise un jeu de mot animalier. D'autres, encore en activité aiment aussi les animaux:
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
    | Les fans de mathématiques pourront se rendre au choix chez:
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
    | Tandis que les littéraires seront plus attirés par:
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
    | Les informaticiens ne sont pas en reste avec
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
    | De nombreuses possibilités pour intégrer son nom dans celui de son salon:
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
    | Plusieurs salons ont un nom en rapport avec la région:
    ul
      li
        a target='_blank' href='#{gmap_url("CORS'HAIR", db_get_addresse_by_name(db, "CORS'HAIR"))}'
          | CORS'HAIR
        |  à Saint-Malo
      li
        a target='_blank' href='#{gmap_url("FINIST'HAIR", db_get_addresse_by_name(db, "FINIST'HAIR"))}'
          | FINIST'HAIR
        |  en Bretagne
"""

  content << """
  p
    | Ceux-ci semblent pouvoir fournir des services... 'différents':
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
    | Ces salons n'hésitent pas à chercher dans les références 'Pop':
    ul
"""
  [
    "ABRARACOUR 'TIFS",
    "TIFS ET TONDU",
    "SPEED'HAIR MAN",
    "PRINCE DE BEL HAIR",
    "PARTOUTA'TIF",
    "GIJHAIR",
  ].each do |n|
    content << "      li\n        a target='_blank' href='#{gmap_url(n, db_get_addresse_by_name(db, n))}'\n         | #{n}\n"
  end

  content << """
  p
    | Une séléction de noms très originaux:
    ul
"""
  [
    "LA CHAMBRE A HAIR",
    "VENT'CONTR'HAIR",
    "TRALAL'HAIR",
    "SAGIT HAIR",
    "REVOLVHAIR",
    "RECUP'HAIR",
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
    "BOUC ET MISS HAIR",
  ].each do |n|
    content << "      li\n        a target='_blank' href='#{gmap_url(n, db_get_addresse_by_name(db, n))}'\n         | #{n}\n"
  end

  content << """
  p
    | Certains salons semblent avoir tenté des jeux de mots, pas tout à fait heureux, ou avec le mauvais champs lexical:
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
    | En listant les mots utilisés par chaque établissement, trié par ordre d'apparition, et filtré sur le champs lexical de la coiffure a également permis de déterrer quelsques perles comme:
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
    | Mais le plus drôle de tous reste:
    ul
"""
  [
      "MD'HAIR"
  ].each do |n|
    content << "      li\n        a target='_blank' href='#{gmap_url(n, db_get_addresse_by_name(db, n))}'\n         | #{n}\n"
  end

  content << """
  p
    | Pour finir, il semble que depuis le début de l'enregistrement des établissements dans la base de l'INSEE, aucun salon de coiffure ne se soit appelé:
    ul
      li
        | 'Apéritif'
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
make_dept_geojson(db_file, File.join(source_dir, "geojson", "departements-avec-outre-mer.geojson" ), File.join(dest_dir, "departements.geojson"))
make_json(db_file, dest_dir, $blague)

build_stats(db_file, File.join(source_dir, "stats.slim"))

slimify(File.join(source_dir, "main.slim"), File.join(dest_dir, "index.html"))
copy_dir(File.join(source_dir, 'css' ), dest_dir)
copy_dir(File.join(source_dir, 'js'), dest_dir)
copy_dir(File.join(source_dir, 'pics'), dest_dir)
copy_dir(File.join(source_dir, 'geojson'), dest_dir)

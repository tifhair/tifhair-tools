require "uri"
require "fileutils"
require "json"
require "slim"
require "sqlite3"

blague = 'etat = "A" AND (name LIKE "%tif%" OR name LIKE "%hair%" OR name LIKE "%epi%" OR name LIKE "%mech%") ORDER BY RANDOM()'

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
        "markerinnerhtml" => "<p>#{nom}</p><a target='_blank' href='https://maps.google.com/?q=#{URI.encode_www_form_component(nom)} #{addresse}'>#{addresse}</a>",
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

def slimify(slim_template, dest)
  File.open(dest, 'w') do |f|
    content = Slim::Template.new(slim_template).render()
    f.write(content)
  end
  puts "written #{dest}"
end

def copy_dir(source, dest)
  FileUtils.cp_r(source, dest, verbose:true)
end

make_json(File.join(source_dir, "coiffeurs.sqlite"), dest_dir, blague)
slimify(File.join(source_dir, "main.slim"), File.join(dest_dir, "index.html"))
slimify(File.join(source_dir, "infos.slim"), File.join(dest_dir, "infos.html"))
copy_dir(File.join(source_dir, 'css' ), dest_dir)
copy_dir(File.join(source_dir, 'js'), dest_dir)

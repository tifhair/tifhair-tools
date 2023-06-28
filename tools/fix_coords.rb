# Fix coords with google maps url
require "sqlite3"

if ARGV.size < 3
  raise "ruby fix_coords.rb coiffeurs.sqlite gmap_url siret <Coiffeurs>"
end

db_file = ARGV[0]
gmap_url = ARGV[1]
siret = ARGV[2]
$table_name = ARGV[3]
if not $table_name
  $table_name = "Coiffeurs"
end

if not File.exist?(db_file)
  raise "#{db_file} does not exist"
end

db = SQLite3::Database.open(db_file)


lat,lng = gmap_url.split('@')[1].split("/")[0].split(",")[0..1]

lat = lat.to_f
lng = lng.to_f

if lat == 0 or lng == 0
  raise Exception.new("Can't find lat,lng in gmap url")
end

db.execute("UPDATE #{$table_name} set lat=?, lng=? WHERE siret=?", lat, lng, siret)

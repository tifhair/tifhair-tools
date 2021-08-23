require "geocoder"
require "progressbar"
require "sqlite3"

$google=false

db_file = ARGV[0]

if ARGV.size==2
  $google=true
  Geocoder.configure(
    lookup: :google,
    api_key: File.read([ARGV[1]]).strip()
  )
else
  Geocoder.configure(
    lookup: :ban_data_gouv_fr
  )
end


db = SQLite3::Database.open(db_file)
def update_with_google(db, row)
  siret,  a, b, c, d = row
  address = [a,b,c,d].join(' ').strip
  res = Geocoder.search(address)[0]
  if res
    lat = res.data["geometry"]["location"]["lat"]
    lng = res.data["geometry"]["location"]["lng"]
    pp lat,lng
    if res.data["plus_code"]
      code = res.data["plus_code"]["global_code"]
    end
    db.execute('UPDATE Coiffeurs SET lat=?, lng=?, global_code=?  WHERE siret = ?', lat, lng, code, siret)

  end
end

def update_with_gouvfr(db, row)
  siret, a, b, c, d = row
  address = [a,b,c,d].join(' ').strip
  res = Geocoder.search(address)[0]
  if res
    lng, lat =  res.data['features'][0]['geometry']['coordinates']
    db.execute('UPDATE Coiffeurs SET lat=?, lng=? WHERE siret = ?', lat, lng, siret)
  end
end

coiffeurs = db.execute("SELECT siret, numero_rue, voie, codepostal, ville FROM Coiffeurs WHERE etat='A' AND lat IS NULL")
total = coiffeurs.size()
progressbar = ProgressBar.create(total: total, format: '%a %e %P% Processed: %c from %C')
coiffeurs.each do |row|
  progressbar.increment

  if $google
    update_with_google(db, row)
  else
    update_with_gouvfr(db, row)
  end
end
progressbar.finish

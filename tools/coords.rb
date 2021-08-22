require "geocoder"
require "sqlite3"

$google=false

if ARGV[0] == "google"
  $google=true
  Geocoder.configure(
    lookup: :google,
    api_key: File.read('.api_key').strip()
  )
else
  Geocoder.configure(
    lookup: :ban_data_gouv_fr
  )
end


db = SQLite3::Database.open("../coiffeurs.sqlite")
def update_with_google(row) 
  siret, name, a, b, c, d = row
  address = [a,b,c,d].join(' ').strip
  puts name
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

def update_with_gouvfr(row)
  siret, name, a, b, c, d = row
  address = [a,b,c,d].join(' ').strip
  puts name
  res = Geocoder.search(address)[0]
  if res
    lng, lat =  res.data['features'][0]['geometry']['coordinates']
    db.execute('UPDATE Coiffeurs SET lat=?, lng=? WHERE siret = ?', lat, lng, siret)
  end
end

coiffeurs = db.execute("SELECT siret, name, numero_rue, voie, codepostal, ville FROM Coiffeurs WHERE etat='A' AND lat IS NULL")
total = coiffeurs.size()
done = 0
coiffeurs.each do |row|
  if $google
    update_with_google(row)
  else
    update_with_gouvfr(row)
  end
  done+=1
  puts "#{done}/#{total} : #{done*100/total}"
end

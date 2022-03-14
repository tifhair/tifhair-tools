require "csv"
require "geocoder"
require "progressbar"
require "sqlite3"
require "tempfile"

$google=false

db_file = ARGV[0]

if ARGV.size == 0
  raise "ruby coords.rb <coiffeurs.sqlite>"
end

if not File.exist?(db_file)
  raise "#{db_file} does not exist"
end

if ARGV.size==2
  $google=true
  Geocoder.configure(
    lookup: :google,
    api_key: File.read(ARGV[1]).strip()
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
    if res.data["plus_code"]
      code = res.data["plus_code"]["global_code"]
    end
    db.execute('UPDATE Coiffeurs SET lat=?, lng=?, global_code=?  WHERE siret = ?', lat, lng, code, siret)

  end
end

def post(url, file)
  uri = URI.parse(url)
  req= Net::HTTP::Post.new(uri)

  form_data = [
    ['result_columns', 'latitude'],
    ['result_columns', 'longitude'],
      ['data', File.open(file, 'r')]
    ]
  req.set_form form_data, 'multipart/form-data'

  Net::HTTP.start(uri.hostname, uri.port, :use_ssl => url.start_with?('https://')) do |http|
    res = http.request(req)
    return res.body
  end
end

def update_with_gouvfr(db, rows)
  file = Tempfile.new('geo')
  csv_string = CSV.generate(headers: "siret,housenumber,street,postcode,city", write_headers: true) do |csv|
    rows.each do |row|
      siret, numero, voie, cp ,ville = row
      csv << [siret, numero, voie, cp, ville]
    end
  end
  file.write(csv_string)
  file.sync()
  file.close()
  csv = CSV.parse(post("https://api-adresse.data.gouv.fr/search/csv/", file), headers: true)
  csv.each do |row|
    # Some weird string conversion is required for siret, I assume otherwise it's turned into an INTEGER
    db.execute('UPDATE Coiffeurs SET lat=?, lng=? WHERE siret = ?', row['latitude'], row['longitude'], "#{row['siret']}")
  end
end

$blague_only = ""
$blague_only = " AND n.blague=1 "
total = db.execute("SELECT count(*) from Coiffeurs as c, Names as n WHERE c.etat='A' AND c.lat IS NULL #{$blague_only}")[0][0]
progressbar = ProgressBar.create(total: total, format: '%a %e %P% Processed: %c from %C')

db.execute("SELECT DISTINCT(c.siret), c.numero_rue, c.voie, c.codepostal, c.ville, n.name FROM Coiffeurs as c, Names as n WHERE etat='A' AND lat IS NULL AND c.siret=n.siret #{$blague_only} GROUP BY c.siret").each_slice(10) do |rows|
    update_with_gouvfr(db, rows)
    progressbar.progress += rows.length
end
progressbar.finish

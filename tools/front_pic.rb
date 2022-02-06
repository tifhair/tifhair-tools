require "fileutils"
require "mechanize"
require "sqlite3"

$dest_front = "photos_front"

def usage()
  puts "ruby front.rb coiffeurs.sqlite"
end

old_db = ARGV[0]
if not old_db or not File.exist?(old_db)
  usage
  exit
end

FileUtils.mkdir_p($dest_front)

mechanize = Mechanize.new

def get_url(m, nom, addresse)
  n = URI.encode_www_form_component(nom)
  a = URI.encode_www_form_component(addresse)
  gmap_url = "https://www.google.com/maps/?q=#{n} #{a}"
  puts gmap_url
  cookie = Mechanize::Cookie.new("CONSENT", "YES+cb.20220201-09-p0.de+FX+794")
  cookie.domain = ".google.com"
  cookie.path = "/"
  m.cookie_jar << cookie
  res = m.get(gmap_url)

  a=res.css("script").select{|x| x.text=~/panoid/}[0].text
  b= a[/APP_INITIALIZATION_STATE=([^;]+);/,1].split('\n')
  c = b.select{|x| x=~/streetviewpixels/}
  e = c.map{|x| x.scan(/streetviewpixels-pa.googleapis.com[^"]+/)[0]}
  #e = d.select{|x| x=~/tactile/}
  pp e
  f = "https://" + e[0][0..-2]
  g= f.gsub("\\\\", "\\").gsub(/\\[uU]\{?([0-9A-F]{4})\}?/i) { $1.hex.chr(Encoding::UTF_8) }
  front_url = g.gsub("&thumbfov=100", "").gsub(/&h=\d+/, "&h=768").gsub(/&w=\d+/, "&w=1024")
  return front_url

end

$olddb = SQLite3::Database.open(old_db)

front_url = ""
while front_url == ""
  begin
    siret, name, num, voie, ville = $olddb.execute("SELECT siret, name, numero_rue, voie, ville from coiffeurs where blague=1 ORDER BY RANDOM() LIMIT 1")[0]
    exist_f = Dir.glob(File.join($dest_front, siret+"*"))
    if exist_f.size != 0
      puts "Already downloaded #{exist_f[0]}"
      exit
    end
    addresse = [num, voie, ville].join(' ').strip()
    out_file = File.join($dest_front, "#{siret}_#{name.split(/[' \-_]/).join('_')}.jpg")
    front_url = get_url(mechanize, name, addresse)
  rescue SignalException
    exit
  rescue Exception => e
    puts "failed to get front URL for #{name} #{addresse}"
    raise e
    exit
  end
end
puts "Download #{front_url} to #{out_file}"
mechanize.download(front_url, out_file)

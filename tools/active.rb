require "csv"
require "curb"
require "nokogiri"
require "sqlite3"

def is_active2(siret)
  c = Curl.post("https://www.sirene.fr/sirene/public/recherche", {"recherche.sirenSiret" => siret, "__checkbox_recherche.excludeClosed"=>"false"})
  c.perform
  begin
  root = Nokogiri::HTML.parse(c.body)
  active = root.css("span.echo-middle p")[0].text.strip == "Actif"
  rescue Exception => e
    if root.css("div#non-diffusible strong span")[0].text.strip=="Établissement non diffusible"
      return 0
    else
      raise "error with #{siret}"
    end
  end
  return active ? 1: 0
end

db = SQLite3::Database.open("coiffeurs.sqlite")

last_actives = [1]*20

all = `wc -l "#{ARGV[0]}" | cut -d " " -f 1`.strip().to_i
done = 0

CSV.foreach(ARGV[0], col_sep: "|", headers:true) do |l|
  if db.execute("SELECT * FROM Coiffeurs WHERE siret = ?", l['siret']).empty?
    active = is_active2(l['siret'])
    last_actives << active
    if last_actives[-20..-1].sum == 0
      raise "Too many not actives"
    end
    puts "#{l['siret']} is active: #{active} (#{done}/#{all} = #{100.0*done/all}%)"
    db.execute("UPDATE Coiffeurs SET active=? WHERE siret=?",
              active,
              l['siret'],
              )
  end
  done +=1
end

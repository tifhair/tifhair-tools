require "csv"
require "sqlite3"

if ARGV.size < 2
  raise "ruby fix_main.rb <coiffeurs.sqlite> fix_file"
end

db_file = ARGV[0]
fix_file = ARGV[1]

if not File.exist?(db_file)
  raise "#{db_file} does not exist"
end

db = SQLite3::Database.open(db_file)

db.execute("UPDATE Names set main=1")

to_fix = File.open(fix_file).read().each_line.map{|x| x.strip.split("|")}

res = db.execute("select c.siret, c.lat, c.lng, n.name, n.main from Coiffeurs as c, Names as n where c.siret=n.siret and n.blague=1 and c.etat='A' ORDER BY c.siret")
all_doubles = {}

res.each do |x|
  siret, lat, lng, name, main = x
  (all_doubles[[lat, lng]] ||= [])  << x
end

todo = all_doubles.select{|k,v| v.size >1}
todo.each do |k,v|
  lat,lng = k
  v.each do |n|
    siret, lat, lng, name, main = n
    if to_fix.include?([siret,name])
      puts "keep #{siret} #{name}"
      db.execute("UPDATE Names set main=1 where siret=? and name=?", siret, name)
    else
      puts "throw #{siret} #{name}"
      db.execute("UPDATE Names set main=0 where siret=? and name=?", siret, name)
    end
  end
end

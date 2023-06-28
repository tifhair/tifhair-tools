require "csv"
require "sqlite3"

$google=false

db_file = ARGV[0]
$table_name = ARGV[1]
if not $table_name
  $table_name = "Coiffeurs"
end


if ARGV.size == 0
  raise "ruby main.rb <coiffeurs.sqlite>"
end

if not File.exist?(db_file)
  raise "#{db_file} does not exist"
end

db = SQLite3::Database.open(db_file)

res = db.execute("select c.siret, c.lat, c.lng, n.name, n.main from #{$table_name} as c, Names as n where c.siret=n.siret and n.blague=1 and c.etat='A' ORDER BY c.siret")
all_doubles = {}

res.each do |x|
  siret, lat, lng, name, main = x
  (all_doubles[[lat, lng]] ||= [])  << x
end

todo = all_doubles.select{|k,v| v.size >1}.select{|k,v| not (v.map{|p| p[4]}).include?(0)}
puts "to do: #{todo.size}"
todo.each do |k,v|
  i = 0
  puts v.map{|x| a="[#{i}]#{x[3]}(#{x[0]})"; i+=1; a}.join(", ")+ "\thttp://www.google.com/maps/place/#{v[0][1]},#{v[0][2]}"

  puts "?"
  nb = $stdin.gets().strip
  while not nb=~/^[0-9]+$/
    puts "?"
    nb = $stdin.gets().strip
  end
  nb = nb.to_i
  i=0
  v.each do |l|
    if i == nb
      db.execute("UPDATE Names set main=1 WHERE siret=? and name=?", l[0], l[3])
    else
      db.execute("UPDATE Names set main=0 WHERE siret=? and name=?", l[0], l[3])
    end
    i+=1
  end
end

require "sqlite3"

dbfile = ARGV[0]

$blague = 'etat = "A" AND (name LIKE "%tif%" OR name LIKE "%hair%" OR name LIKE "%epi%" OR name LIKE "%mech%")'
db = SQLite3::Database.open(dbfile)

# Les classiques
db.execute("UPDATE Coiffeurs set blague=1 WHERE name LIKE '%atmos%air%'")
db.execute("UPDATE Coiffeurs set blague=1 WHERE name LIKE '%hair%du%te%'")
db.execute("UPDATE Coiffeurs set blague=1 WHERE name LIKE '%imagin%air%'")
db.execute("UPDATE Coiffeurs set blague=1 WHERE name LIKE '%bull%d%hair%'")
db.execute("UPDATE Coiffeurs set blague=1 WHERE name LIKE '%ara%t%hair%'")
db.execute("UPDATE Coiffeurs set blague=1 WHERE name LIKE '%PLANET'HAIR%'")
db.execute("UPDATE Coiffeurs set blague=1 WHERE name LIKE '%PIL%HAIR%'")
db.execute("UPDATE Coiffeurs set blague=1 WHERE name LIKE '%infini%tif%'")
db.execute("UPDATE Coiffeurs set blague=1 WHERE name LIKE '%imagina%tif%'")
db.execute("UPDATE Coiffeurs set blague=1 WHERE name LIKE '%evolu%tif%'")
db.execute("UPDATE Coiffeurs set blague=1 WHERE name LIKE '%instinc%tif%'")
db.execute("UPDATE Coiffeurs set blague=1 WHERE name LIKE '%univ%hair%'")
db.execute("UPDATE Coiffeurs set blague=1 WHERE name LIKE '%de meche avec%'")
db.execute("UPDATE Coiffeurs set blague=1 WHERE name LIKE '%beautiful%'")

i=0
tab = db.execute("SELECT name, Count(name) as cnt FROM Coiffeurs WHERE #{$blague} AND blague IS NULL GROUP BY name ORDER BY name DESC")
total = tab.size()
tab.each do |row|
  puts "#{row[0]}  --- #{row[1]} (#{i}/#{total} #{i*100.0/total})"
  i+=1

  toto = STDIN.gets()
  if toto=~/[a-z]{1}/i
    db.execute("UPDATE Coiffeurs set blague=0 where name = ?", row[0])
  else
    # ne rien indiquer = blague
    db.execute("UPDATE Coiffeurs set blague=1 where name = ?", row[0])
  end
end

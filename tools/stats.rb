require "sqlite3"

dbfile = ARGV[0]

db = SQLite3::Database.open(dbfile)

def get_coiffeurs_by_dept(db_file, dept)
  d = dept
  if d == "2A"
    d = "20"
  end
  if d== "2B"
    d = "20"
  end
  db = SQLite3::Database.open(db_file)
  res = db.execute("SELECT count(*) FROM Coiffeurs WHERE codepostal LIKE ? AND blague=1", d+"%")
  blagueurs =  res[0][0]
  res = db.execute("SELECT count(*) FROM Coiffeurs WHERE codepostal LIKE ?", d+"%")
  tous  =  res[0][0]
  percent = 100.0 * blagueurs / tous 
  return percent
end

pp get_coiffeurs_by_dept(dbfile, "43")
exit

"01".upto("97") do |c| 
  puts "#{get_coiffeurs_by_dept(dbfile, c)} #{c}"
end

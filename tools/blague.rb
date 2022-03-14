require "set"
require "sqlite3"
require 'optparse'
require "progressbar"


def usage
  puts "Usage: ruby blague.rb --db=<sqlite> [--bad=file1] [--good=file2]"
  puts "   --db pointe vers le fichier SQLite3 des coiffeurs généré avec sirene.rb"
  puts "   [--bad] est un fichier optionel contenant une liste de noms connus pour ne pas être drôle"
  puts "   [--good] est un fichier optionel contenant une liste de noms connus pour être hilarant"
  exit
end


options = {}
OptionParser.new do |opt|
  opt.on('--db FILE') { |o| options[:db] = o }
  opt.on('--bad FILE') { |o| options[:list_bad] = o }
  opt.on('--good FILE') { |o| options[:list_good] = o }
end.parse!

if not options[:db] or not File.exist?(options[:db])
  pp "Pas de fichier #{options[:db]} trouvé"
  usage
end
dbfile = options[:db]

$bad_chars = /[-\.'&, ]/

$bad_names = []
if options[:list_bad]
  if not File.exist?(options[:list_bad])
    puts "Impossible de trouver le fichier #{options[:list_bad]}"
    usage
  end
  $bad_names = Set.new(File.open(options[:list_bad]).each_line.map{|l| l.gsub($bad_chars, "").strip()}.to_a)
  puts "Chargé #{$bad_names.size} non blagues"
end

$good_names = []
if options[:list_good]
  if not File.exist?(options[:list_good])
    puts "Impossible de trouver le fichier #{options[:list_good]}"
    usage
  end
  $good_names = Set.new(File.open(options[:list_good]).each_line.map{|l| l.gsub($bad_chars,"").strip()}.to_a)
  puts "Chargé #{$good_names.size} blagues"
end
db = SQLite3::Database.open(dbfile)

def is_blague(name)
  return false if name.size < 5

  if $good_names.include?(name.gsub($bad_chars,""))
    return true
  end
  if $bad_names.include?(name.gsub($bad_chars,""))
    return false
  end

  puts "Nouveau nom #{name} \nEst-ce que c'est drole ? [y/N]"
  res = $stdin.gets().strip

  if res=~/^n?$/i
    $bad_names << name.gsub($bad_chars,"")
    return false
  end
  puts "good"
  $good_names << name.gsub($bad_chars,"")
  return true
end


i=0
# All
likes = ""
# Potentielles blagues
#likes = "AND (n.name LIKE "+ ["poux", "poil", "brun", "blon", "dread", "lock","tress", "un chev", "aqua%fur%", "raie", "boucl", "chauv", "tiph","point","frang", "hom", "head", "coup", "long", "cour", "racin", "t'if", "h'air", "fris," "cis", "mech", "mesh", "tyf","mel", "peig", "hair","tif","epi", "tete", "afro"].map{|x| "\"%"+x+"%\""}.join(" OR n.name LIKE ") + ")"
tab = db.execute("SELECT c.siret, n.name, c.ville FROM Coiffeurs as c, Names as n WHERE c.etat='A' AND blague IS NULL AND c.siret = n.siret #{likes} ORDER BY n.name DESC;")
total = tab.size()
progressbar = ProgressBar.create(total: total, format: '%a %e %P% Processed: %c from %C')
tab.each do |row|
  begin
    progressbar.progress += 10 if i%10 ==0
  rescue
  end
  i+=1
  puts "#{row[2]} "
  if is_blague(row[1])
    db.execute("UPDATE Names set blague=1 where name=?", row[1])
  else
    db.execute("UPDATE Names set blague=0 where name=?", row[1])
  end
end
progressbar.finish

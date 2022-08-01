require "date"
require "set"
require "fileutils"
require "sqlite3"
require "progressbar"
require 'ruby-prof'
require "stackprof"

STDOUT.sync = true

$groupconcat_sep = '"@@"'

old_db = ARGV[0]
if not old_db or not File.exist?(old_db)
  usage
  exit
end

new_db = ARGV[1]
if not new_db or not File.exist?(new_db)
  usage
  exit
end

# Backup orig db
FileUtils.cp(old_db, old_db.gsub(/.sqlite$/, "")+"_"+DateTime.now.strftime("%Y%m%d-%H%M%S")+".sqlite")

$olddb = SQLite3::Database.open(old_db)
$newdb = SQLite3::Database.open(new_db)

has_seen = $newdb.execute("SELECT COUNT(*) FROM pragma_table_info('Names') WHERE name='seen'")
if has_seen == [[0]]
  $newdb.execute("ALTER TABLE Names ADD COLUMN seen bool")
  $newdb.execute("UPDATE Names SET seen=0")
end

$olddb.results_as_hash = true
$newdb.results_as_hash = true

$known_lol = Set.new($olddb.execute("SELECT name FROM Names where blague=1").map {|k| k.values[0]}.uniq.sort)
$known_bad = Set.new($olddb.execute("SELECT name FROM Names where blague=0").map {|k| k.values[0]}.uniq.sort)

def usage()
  puts "ruby compare.rb coiffeurs_orig.sqlite coiffeurs_update.sqlite"
end

def is_blague(name, old, new)

  if $known_lol.include?(name)
    return true
  end
  if $known_bad.include?(name)
    return false
  end

  if old == nil
    puts "Nouveau nom #{name} (#{new['ville']}/#{new['codepostal']})"
    puts "Est-ce que c'est drole ? [y/N]"
  else
    puts "Name change from '#{old["names"].join(' | ')}' to '#{name}' (#{new['ville']}/#{new['codepostal']})"
    puts "Est-ce que c'est drole maintenant? [y/N]"
  end
  res = $stdin.gets().strip

  if res=~/^n?$/i
    $known_bad << name
    return false
  end
  $known_lol << name
  return true
end

def add_row(db, row)
  blague = nil
  row["names"].each do |name|
    if row['etat'] == 'A'
      res = is_blague(name, nil, row)
      blague = res ? 1 : 0
    end
    db.execute("INSERT OR IGNORE INTO Names (id, siret, name, blague, main ) VALUES (?,?,?,?, 1)",
              nil,
              row['siret'],
              name,
              blague
              )
  end
  db.execute("INSERT INTO coiffeurs (siret, siren, date, codepostal, ville, numero_rue, voie, lat, lng, global_code,  etat ) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
            row['siret'],
            row['siren'],
            row['date'],
            row['codepostal'],
            row['ville'],
            row['numero_rue'],
            row['voie'],
            row['lat'],
            row['lng'],
            row['global_code'],
            row['etat']
            )
  return true
end

def handle_diff(old, new, auto)
  diff = {}
  ["date", "codepostal", "ville", "numero_rue", "voie", "etat"].each do |c|
    if old[c] != new[c]
      diff[c] = "'#{old[c]}' != '#{new[c]}'"
    end
  end

  if old
    diff["names"] = new["names"] - (old["names"] & new["names"])
  else
    diff["names"] = new["names"]
  end
  return true if diff.empty?

  siret = old['siret']

  diff.each do |c,v|
    case c
    when "names"
      next if v.empty?
      return false if auto
      new["names"].each do |name|
        res = is_blague(name, old, new)
        $olddb.execute("INSERT OR IGNORE INTO Names (id, siret, name, blague ) VALUES (?,?,?,?)", nil, new['siret'], name, 0)
        if res
          $olddb.execute("UPDATE Names SET blague=1 WHERE siret=? AND name=?", siret, name)
        else
          $olddb.execute("UPDATE Names SET blague=0 WHERE siret=? AND name=?", siret, name)
        end
      end
    when "etat"
      if old["etat"] == "A" and new["etat"] == "F"
        $olddb.execute("UPDATE coiffeurs SET etat=? WHERE siret=?", new['etat'], siret)
        break
      else
      return false if auto
        puts "Etablissement connu, mais maintenant actif: #{siret}"
        new["names"].each do |name|
          res = is_blague(name, nil, new)
          if res
            $olddb.execute("UPDATE Names SET blague=1 WHERE siret=?", siret)
          else
            # Non
            $olddb.execute("UPDATE Names SET blague=0 WHERE siret=?", siret)
          end
        end
        $olddb.execute("UPDATE coiffeurs SET etat=? WHERE siret=?", new['etat'], siret)
      end
    when "ville"
      $olddb.execute("UPDATE coiffeurs SET voie=? WHERE siret=?", new['ville'], siret)
      old['ville'] = new['ville']
    when "voie"
      $olddb.execute("UPDATE coiffeurs SET voie=? WHERE siret=?", new['voie'], siret)
      old['voie'] = new['voie']
    when "numero_rue"
      $olddb.execute("UPDATE coiffeurs SET numero_rue=? WHERE siret=?", new['numero_rue'], siret)
      old['numero_rue'] = new['numero_rue']
    when "codepostal"
        $olddb.execute("UPDATE coiffeurs SET codepostal=? WHERE siret=?", new['codepostal'], siret)
        old['codepostal'] = new['codepostal']
    when "date"
    else
      raise Exception.new("Change for #{c}: #{old[c]} != #{new[c]}")
    end
  end
  return true
end


# Load everything into memory

[true, false].each do |auto|
  if auto
    puts "Premiere passe, on verifie pas les noms"
  else
    puts "Deuxieme passe, on verifie les noms"
  end
  puts "loading into memory"
  $select_all_new = "SELECT c.siret as siret, c.siren as siren, c.date as date, c.codepostal as codepostal, c.ville as ville, c.numero_rue as numero_rue, c.voie as voie, c.lat as lat, c.lng as lng, c.global_code as global_code, c.etat as etat, GROUP_CONCAT(n.name, '#{$groupconcat_sep}') as names, n.blague as blague, n.seen as seen FROM Coiffeurs as c, Names as n WHERE c.siret = n.siret AND n.seen=0 GROUP BY c.siret"
  new_list = $newdb.execute($select_all_new)


  $select_all_old = "SELECT c.siret as siret, c.siren as siren, c.date as date, c.codepostal as codepostal, c.ville as ville, c.numero_rue as numero_rue, c.voie as voie, c.lat as lat, c.lng as lng, c.global_code as global_code, c.etat as etat, GROUP_CONCAT(n.name, '#{$groupconcat_sep}') as names, n.blague as blague, n.seen as seen FROM Coiffeurs as c, Names as n WHERE c.siret = n.siret GROUP BY c.siret"
  old_list = $olddb.execute($select_all_old)

  new_list.each do |new|
    new["names"] = new["names"].split($groupconcat_sep).sort
  end
  new_list.sort_by{|x| x['siret']}

  old_hash = {}
  old_list.each do |old|
    old["names"] = old["names"].split($groupconcat_sep).sort
    old_hash[old['siret']] = old
  end

  done = 0
  progressbar = ProgressBar.create(total: new_list.size, format: '%a %e %P% Processed: %c from %C')
  new_list.each do |n|
    progressbar.progress += 50 if done>0 and done%50 == 0
    siret = n["siret"]
    old_entry = old_hash[siret]
    if not old_entry
      # Nouveau siret
      next if auto
      add_row($olddb, n)
      $newdb.execute("UPDATE Names set seen=1 WHERE siret=?", siret)
      done += 1
    else
      res = handle_diff(old_entry, n, auto)
      if res
        $newdb.execute("UPDATE Names set seen=1 WHERE siret=?", siret)
        done += 1
      end
    end
  end
end

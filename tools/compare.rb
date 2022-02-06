require "date"
require "fileutils"
require "sqlite3"
require "progressbar"

STDOUT.sync = true

def usage()
  puts "ruby compare.rb coiffeurs_orig.sqlite coiffeurs_update.sqlite"
end

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
$olddb.results_as_hash = true
$newdb.results_as_hash = true

$select_all = "SELECT siret, siren, name, date, codepostal, ville, numero_rue, voie, lat, lng, global_code, blague, etat FROM Coiffeurs"

stm = $newdb.prepare $select_all + " WHERE seen=0 ORDER BY name"

$known_lol = $olddb.execute("SELECT name FROM Coiffeurs where blague=1").map {|k| k.values[0]}.uniq.sort
$known_bad = $olddb.execute("SELECT name FROM Coiffeurs where blague=0").map {|k| k.values[0]}.uniq.sort


def is_blague(old, new)

  if $known_lol.include?(new)
    return true
  end
  if $known_bad.include?(new)
    return false
  end

  if old == nil
      puts "Nouveau nom #{new}"
      puts "Est-ce que c'est drole ? [y/N]"
  else
      puts "Name change from #{old} to #{new}"
      puts "Est-ce que c'est drole maintenant? [y/N]"
  end
  res = $stdin.gets().strip

  if res=~/^n?$/i
    $known_bad << new
    return false
  end
  $known_lol << new
  return true
end

def handle_diff(old,new)
  diff = {}
  ["name", "date", "codepostal", "ville", "numero_rue", "voie", "etat", "lat", "lng", "global_code", "blague"].each do |c|
    if old[c] != new[c]
      diff[c] = "'#{old[c]}' != '#{new[c]}'"
    end
  end
  return if diff.empty?

  siret = old['siret']

  diff.each do |c,v|
    case c
    when "lat" 
      old_addresse = [old['num'], old['voie'], old['ville']].join(' ').strip()
      new_addresse = [new['num'], new['voie'], new['ville']].join(' ').strip()
      if new["lat"] == nil or new["lat"] == ""
        $newdb.execute("UPDATE coiffeurs SET lat=? WHERE siret=?", old["lat"], siret)
        break
      end
      if old["lat"] == nil or old["lat"] == ""
        $olddb.execute("UPDATE coiffeurs SET lat=? WHERE siret=?", new["lat"], siret)
        break
      end
      if old_addresse == new_addresse
        $newdb.execute("UPDATE coiffeurs SET lat=? WHERE siret=?", old["lat"], siret)
        break
      else
        raise Exception.new("different address and change for lat: #{v}")
      end
      raise Exception.new("siret: #{siret} unhandled case for #{c}: #{v} ")

    when "lng" 
      old_addresse = [old['num'], old['voie'], old['ville']].join(' ').strip()
      new_addresse = [new['num'], new['voie'], new['ville']].join(' ').strip()
      if new["lng"] == nil or new["lng"] == ""
        $newdb.execute("UPDATE coiffeurs SET lng=? WHERE siret=?", old["lng"], siret)
        break
      end
      if old["lng"] == nil or old["lng"] == ""
        $olddb.execute("UPDATE coiffeurs SET lng=? WHERE siret=?", new["lng"], siret)
        break
      end
      if old_addresse == new_addresse
        $newdb.execute("UPDATE coiffeurs SET lng=? WHERE siret=?", old["lng"], siret)
        break
      else
        raise Exception.new("different address and change for lng: #{v} ")
      end
      raise Exception.new("siret: #{siret} unhandled case for #{v} ")

    when "global_code"
      if new["global_code"] == nil or new["global_code"] == ""
        $newdb.execute("UPDATE coiffeurs SET global_code=? WHERE siret=?", old["global_code"], siret)
        break
      end
      raise Exception.new("siret: #{siret} unhandled case for #{c}: #{v} ")

    when "name"
      res = is_blague(old[c], new[c])
      if res 
        $olddb.execute("UPDATE coiffeurs SET blague=1 WHERE siret=?", siret)
      else
        $olddb.execute("UPDATE coiffeurs SET blague=0 WHERE siret=?", siret)
      end
      $olddb.execute("UPDATE coiffeurs SET name=? WHERE siret=?", new[c], siret)
    when "blague"
    when "etat"
      if old["etat"] == "A" and new["etat"] == "F"
        $olddb.execute("UPDATE coiffeurs SET etat=? WHERE siret=?", new['etat'], siret)
        break
      else
        puts "Etablissement connu, mais maintenant actif: #{siret}" 
        res = is_blague(nil, new['name'])
        if res 
          $olddb.execute("UPDATE coiffeurs SET blague=1 WHERE siret=?", siret)
        else
          # Non
          $olddb.execute("UPDATE coiffeurs SET blague=0 WHERE siret=?", siret)
        end
        $olddb.execute("UPDATE coiffeurs SET etat=? WHERE siret=?", new['etat'], siret)
      end
    when "ville"
      puts "Accepter Nouveau 'ville'? [Y/n]"
      res = $stdin.gets().strip() 
      if res == ""
          $olddb.execute("UPDATE coiffeurs SET voie=? WHERE siret=?", new['ville'], siret)
          old['ville'] = new['ville']
      else
        raise Exception.new("I don't know what to do :(")
      end
    when "date"
      $olddb.execute("UPDATE coiffeurs SET date=? WHERE siret=?", new['date'], siret)
    when "voie"
      puts "Accepter Nouveau 'voie'? [Y/n]"
      res = $stdin.gets().strip() 
      if res == ""
          $olddb.execute("UPDATE coiffeurs SET voie=? WHERE siret=?", new['voie'], siret)
          old['voie'] = new['voie']
      else
        raise Exception.new("I don't know what to do :(")
      end
    when "numero_rue"
      puts "Accepter Nouveau 'numero_rue'? [Y/n]"
      res = $stdin.gets().strip() 
      if res == ""
          $olddb.execute("UPDATE coiffeurs SET numero_rue=? WHERE siret=?", new['numero_rue'], siret)
          old['numero_rue'] = new['numero_rue']
      else
        raise Exception.new("I don't know what to do :(")
      end
    when "codepostal"
      puts "Accepter Nouveau 'codepostal'? [Y/n]"
      res = $stdin.gets().strip() 
      if res == ""
          $olddb.execute("UPDATE coiffeurs SET codepostal=? WHERE siret=?", new['codepostal'], siret)
          old['codepostal'] = new['codepostal']
      else
        raise Exception.new("I don't know what to do :(")
      end
    else
      raise Exception.new("Change for #{c}: #{old[c]} != #{new[c]}")
    end
  end
end

def add_row(db, row)
  if row['etat'] == 'A'
    res = is_blague(nil, row['name'])
    blague = res ? 1 : 0
  end
  db.execute("INSERT INTO coiffeurs (siret, siren, name, date, codepostal, ville, numero_rue, voie, lat, lng, global_code,  blague, etat ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
            row['siret'],
            row['siren'],
            row['name'],
            row['date'],
            row['codepostal'],
            row['ville'],
            row['numero_rue'],
            row['voie'],
            row['lat'],
            row['lng'],
            row['global_code'],
            blague,
            row['etat']
            )
end

to_do = $newdb.execute("select count(*) from coiffeurs where seen=0")[0]["count(*)"]
done = 0

stm.execute.each do |row|
  puts "Progress: #{done}/#{to_do} #{100*done/to_do}%"
  old_rows = $olddb.execute($select_all+" WHERE siret = ?", row['siret'])
  if old_rows.size > 1
    raise Exception("Shouldn't have more than 1 row for siret #{row['siret']}")
  elsif old_rows.size ==  1
    handle_diff(old_rows[0], row)
  elsif old_rows.size == 0
      add_row($olddb, row)
  end
  $newdb.execute("UPDATE coiffeurs set seen=1 WHERE siret=?", row['siret'])
  done+=1
end

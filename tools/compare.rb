require "date"
require "set"
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

has_seen = $newdb.execute("SELECT COUNT(*) FROM pragma_table_info('Names') WHERE name='seen'")
if has_seen == [[0]]
  $newdb.execute("ALTER TABLE Names ADD COLUMN seen bool")
  $newdb.execute("UPDATE Names SET seen=0")
end

$olddb.results_as_hash = true
$newdb.results_as_hash = true


$select_all_new = "SELECT c.siret as siret, c.siren as siren, c.date as date, c.codepostal as codepostal, c.ville as ville, c.numero_rue as numero_rue, c.voie as voie, c.lat as lat, c.lng as lng, c.global_code as global_code, c.etat as etat, n.name as name, n.blague as blague, n.seen as seen FROM Coiffeurs as c, Names as n WHERE c.siret = n.siret"
$select_all_old = "SELECT c.siret as siret, c.siren as siren, c.date as date, c.codepostal as codepostal, c.ville as ville, c.numero_rue as numero_rue, c.voie as voie, c.lat as lat, c.lng as lng, c.global_code as global_code, c.etat as etat, n.name as name, n.blague as blague FROM Coiffeurs as c, Names as n WHERE c.siret = n.siret"

$known_lol = Set.new($olddb.execute("SELECT name FROM Names where blague=1").map {|k| k.values[0]}.uniq.sort)
$known_bad = Set.new($olddb.execute("SELECT name FROM Names where blague=0").map {|k| k.values[0]}.uniq.sort)


def is_blague(old, new)
  old_name = ""
  new_name = ""
  if old
    old_name = old['name']
  end
  if new
    new_name = new['name']
  end

  if $known_lol.include?(new_name)
    return true
  end
  if $known_bad.include?(old_name)
    return false
  end

  if old == nil
      puts "Nouveau nom #{new_name} (#{new['ville']}/#{new['codepostal']})"
      puts "Est-ce que c'est drole ? [y/N]"
  else
      puts "Name change from '#{old_name}' to '#{new_name}' (#{new['ville']}/#{new['codepostal']})"
      puts "Est-ce que c'est drole maintenant? [y/N]"
  end
  res = $stdin.gets().strip

  if res=~/^n?$/i
    $known_bad << new_name
    return false
  end
  $known_lol << new_name
  return true
end

def handle_diff(old,new, auto)
  diff = {}
  ["name", "date", "codepostal", "ville", "numero_rue", "voie", "etat", "lat", "lng", "global_code", "blague"].each do |c|
    if old[c] != new[c]
      diff[c] = "'#{old[c]}' != '#{new[c]}'"
    end
  end
  return true if diff.empty?

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
      if auto
        # We are in auto mode, skip for now
        return false
      end
      res = is_blague(old, new)
      if res 
        $olddb.execute("UPDATE Names SET blague=1 WHERE siret=? AND name=?", siret, old)
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
        if auto
          # We are in auto mode, skip for now
          return false
        end
        puts "Etablissement connu, mais maintenant actif: #{siret}" 
        res = is_blague(nil, new)
        if res 
          $olddb.execute("UPDATE coiffeurs SET blague=1 WHERE siret=?", siret)
        else
          # Non
          $olddb.execute("UPDATE coiffeurs SET blague=0 WHERE siret=?", siret)
        end
        $olddb.execute("UPDATE coiffeurs SET etat=? WHERE siret=?", new['etat'], siret)
      end
    when "ville"
      $olddb.execute("UPDATE coiffeurs SET voie=? WHERE siret=?", new['ville'], siret)
      old['ville'] = new['ville']
    when "date"
      $olddb.execute("UPDATE coiffeurs SET date=? WHERE siret=?", new['date'], siret)
    when "voie"
      $olddb.execute("UPDATE coiffeurs SET voie=? WHERE siret=?", new['voie'], siret)
      old['voie'] = new['voie']
    when "numero_rue"
      $olddb.execute("UPDATE coiffeurs SET numero_rue=? WHERE siret=?", new['numero_rue'], siret)
      old['numero_rue'] = new['numero_rue']
    when "codepostal"
        $olddb.execute("UPDATE coiffeurs SET codepostal=? WHERE siret=?", new['codepostal'], siret)
        old['codepostal'] = new['codepostal']
    else
      raise Exception.new("Change for #{c}: #{old[c]} != #{new[c]}")
    end
  end
  return true
end

def add_row(db, row, auto)
  blague = nil
  if row['etat'] == 'A'
    if auto
      return false
    end
    res = is_blague(nil, row)
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
  return true
end


to_do = $newdb.execute("select count(*) from Names where seen=0")[0]["count(*)"]
done = 0

[true, false].each do |auto|
  if auto
    puts "First pass, automatic review"
  else
    puts "Second pass, manual review"
  end

  begin
    stm = $newdb.prepare $select_all_new + " AND n.seen=0 ORDER BY n.name"
  rescue SQLite3::SQLException
    $newdb.execute("alter TABLE Names ADD COLUMN seen bool")
    $newdb.execute("UPDATE Names set seen=0")
    retry
  end

  stm.execute.each do |row|
    puts "Progress: #{done}/#{to_do} #{100*done/to_do}%" if done%50==0
    pp $select_all_old+" AND c.siret = "+ row['siret']
    old_rows = $olddb.execute($select_all_old+" AND c.siret = ?", row['siret'])
    if old_rows.size > 1
      raise Exception("Shouldn't have more than 1 row for siret #{row['siret']}")
    elsif old_rows.size ==  1
      res = handle_diff(old_rows[0], row, auto)
      if res
        $newdb.execute("UPDATE coiffeurs set seen=1 WHERE siret=?", row['siret'])
        done += 1
      else
        puts "First pass: skipping #{row} "
      end
    elsif old_rows.size == 0
      pp row
      res = add_row($olddb, row, auto)
      if res
        $newdb.execute("UPDATE coiffeurs set seen=1 WHERE siret=?", row['siret'])
        done += 1
      else
        puts "First Pass: skipping #{row}"
      end
    end
  end
end

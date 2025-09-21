require "sqlite3"
require "json"

if ARGV.empty?
  raise "ruby anomalies.rb <coiffeurs.sqlite>"
end

db_file = ARGV[0]
$table_name = ARGV[1] || "Coiffeurs"

unless File.exist?(db_file)
  raise "#{db_file} does not exist"
end

def load_depts(json_file)
  res = {}
  corse = []
  j = JSON.parse(File.read(json_file))
  j["features"].each do |f|
    dept = f["properties"]["code"]
    case f["geometry"]["type"]
    when "MultiPolygon"
      if ["2A", "2B"].include?(dept)
        corse += f["geometry"]["coordinates"].map { |x| x[0] }
      else
        res[dept] = f["geometry"]["coordinates"].map { |x| x[0] }
      end

    when "Polygon"
      res[dept] = f["geometry"]["coordinates"]
    else
      raise StandardError, "Unknown type #{f['type']}"
    end
  end
  res["20"] = corse
  return res
end

def point_in_dept(x, y, dept)
  res = false
  dept.each do |poly|
    num = poly.size
    j = num - 1
    c = false
    0.upto(j) do |i|
      if (x == poly[i][0]) and (y == poly[i][1])
        # point is a corner
        res ||= true
        break
      end
      if (poly[i][1] > y) != (poly[j][1] > y)
        slope = (x - poly[i][0]) * (poly[j][1] - poly[i][1]) - (poly[j][0] - poly[i][0]) * (y - poly[i][1])
        if slope == 0
          # point is on boundary
          res ||= true
          break
        end
        if (slope < 0) != (poly[j][1] < poly[i][1])
          c = !c
        end
      end
      j = i
    end
    res = c || res
  end
  return res
end

def check_coords_in_depts(db)
  depts = load_depts(File.join(__dir__, "../src/geojson//departements-avec-outre-mer.geojson"))
  db.execute("SELECT c.lat, c.lng, c.codepostal, c.siret, n.name, c.numero_rue, c.voie, c.ville from #{$table_name} as c, Names as n WHERE c.etat='A' AND c.siret=n.siret AND blague = 1").each do |r|
    next unless r['lat']
    next unless r['codepostal']

    cp = r['codepostal'][0..1]
    if r['codepostal'] =~ /^97/
      cp = r['codepostal'][0..2]
    end

    next if cp == '975' # St Pierre et Miquelon
    next if cp == "[N" # diffusion restreinte

    unless depts[cp]
      raise StandardError, "Unknown cp #{cp}"
    end

    unless point_in_dept(r["lng"].to_f, r["lat"].to_f, depts[cp]) 
      next if r['siret'] == "51014661600055" # tres proche frontiere

      case r['codepostal']
      when "97150"
        #puts "#{r['name']} est à saint-marin (97150)"
      when "97133"
        # puts "#{r['name']} est à saint-Barthélémy (97133)"
      when "97400"
        unless r['siret'] == "31539771100039" # pas réussi à vérifier avec gmaps
          raise StandardError, "#{r['name']} (#{r['siret']} not in #{r['codepostal']} "
        end
      when "40220"
        unless r['siret'] == "48460978900017" # très proche de la frontière
          raise StandardError, "#{r['name']} (#{r['siret']} not in #{r['codepostal']} "
        end

      when "33220"
        unless r['siret'] == "89323532500022" # très proche de la frontière
          raise StandardError, "#{r['name']} (#{r['siret']} not in #{r['codepostal']} "
        end
      else
        puts "#{r['name']} (#{r['siret']} not in #{r['codepostal']}: #{r['lat']} #{r['lng']} #{r['numero_rue']} #{r['voie']} #{r['ville']}"
        raise StandardError, "#{r['name']} (#{r['siret']} not in #{r['codepostal']}: #{r['lat']} #{r['lng']} "
      end
    end
  end
end

database = SQLite3::Database.open(db_file)
database.results_as_hash = true

check_coords_in_depts(database)

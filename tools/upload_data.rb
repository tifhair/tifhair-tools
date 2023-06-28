require 'net/http/post/multipart'

data_key_path = ARGV[0]
dataset = ARGV[1]
ressource = ARGV[2]
json_file = ARGV[3]

def usage
  puts "ruby upload_data.rb <chemin clé api> <dataset> <ressource> <fichier_json>"
end

if not ARGV.size == 4
  usage
  exit
end

if not dataset=~/^[a-f0-9]+$/
  usage
  raise Exception.new("Mauvais format de dataset: '#{dataset}'")
end


if not ressource=~/^[a-f0-9\-]+$/
  usage
  raise Exception.new("Mauvais format de ressource: '#{ressource}'")
end

if not File.exist?(data_key_path)
  usage
  raise Exception.new("Enregistrez votre clé API data.gouv.fr dans un fichier .data_gouv_key")
end
if not File.exist?(json_file)
  usage
  raise Exception.new("impossible de trouver le fichier json #{json_file}")
end

api_key = File.read(data_key_path).strip()

if not api_key=~/^[a-zA-Z0-9\-\.]+$/
  pp api_key
  raise Exception.new("Format de la clé API non valide")
end


api_url = "https://www.data.gouv.fr/api/1/datasets/#{dataset}/resources/#{ressource}/upload/"

def post(url, api_key, file)
  uri = URI.parse(url)
  req = Net::HTTP::Post::Multipart.new(
    uri.path,
    "file" => UploadIO.new(File.new(file), "application/json", "coiffeurs.json")
  )
  req.add_field('X-API-KEY', api_key)
  http = Net::HTTP.new(uri.hostname, uri.port)
  http.use_ssl = url.start_with?('https://')
  res = http.request(req)
  return res
end

pp post(api_url, api_key, json_file)


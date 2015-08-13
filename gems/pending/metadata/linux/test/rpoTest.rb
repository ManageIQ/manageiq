require 'db/MiqBdb/MiqBdb'

db = MiqBerkeleyDB::MiqBdb.new("Name")
v = db.each do |k, v| puts "Name: #{k}:" end
db.close
require 'db/MiqBdb/MiqBdb'

db = MiqBerkeleyDB::MiqBdb.new("Name")
v = db.each { |k, _v| puts "Name: #{k}:" }
db.close

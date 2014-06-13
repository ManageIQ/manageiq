$:.push("#{File.dirname(__FILE__)}/../../../db/MiqBdb")
require 'MiqBdb'

db = MiqBerkeleyDB::MiqBdb.new("Name")
v = db.each do |k, v| puts "Name: #{k}:" end
db.close
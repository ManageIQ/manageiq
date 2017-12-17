#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __dir__)

def print_records(recs, indent = '')
  recs = recs.sort_by { |r| r.name.downcase }
  recs.each do |r|
    puts "#{indent}- #{r.class}: #{r.name}"
    print_records(r.vmdb_indexes, "  #{indent}") if r.kind_of?(VmdbTable)
  end
end

db = VmdbDatabase.includes(:vmdb_tables => :vmdb_indexes).first
puts "VmdbDatabase"
print_records(db.vmdb_tables.where(:type => "VmdbTableEvm"))

puts
puts "Toast Tables"
print_records(db.vmdb_tables.where(:type => "VmdbTableText"), '  ')

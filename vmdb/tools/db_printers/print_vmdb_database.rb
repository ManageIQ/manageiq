def print_records(recs, indent = '')
  recs = recs.sort_by { |r| r.name.downcase }
  recs.each do |r|
    puts "#{indent}- #{r.class}: #{r.name}"
    print_records(r.vmdb_indexes, "  #{indent}") if r.kind_of?(VmdbTable)
  end
end

db = VmdbDatabase.includes(:vmdb_tables => :vmdb_indexes).first
puts "VmdbDatabase"
print_records(db.vmdb_tables.where(:table_type => "vmdb"))

puts
puts "Toast Tables"
print_records(db.vmdb_tables.where(:table_type => "text"), '  ')

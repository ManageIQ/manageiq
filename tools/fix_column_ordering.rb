$LOAD_PATH << Rails.root.join("tools").to_s

require 'column_ordering/column_ordering'

def usage
  <<-EOS
    rails runner fix_column_ordering.rb <table_name>
  EOS
end

table_name = ARGV[0]

puts usage unless table_name

puts "Correcting column ordering for table #{table_name}\n"

begin
  co = ColumnOrdering.new(table_name, ApplicationRecord.connection)
  co.fix_column_ordering
rescue ColumnOrdering::ColumnOrderingError => e
  puts "Failed to reorder columns for table #{table_name}"
  puts e.message
end

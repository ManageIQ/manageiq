#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

connection = ApplicationRecord.connection

puts "CLIENT CONNECTIONS\n==========================================================================="
puts connection.client_connections.tableize(:leading_columns => ['spid'], :trailing_columns => ['query'])
puts "\n\n"

puts "DATABASE STATISTICS\n==========================================================================="
puts connection.statistics.tableize(:leading_columns => ['name'])
puts "\n\n"

puts "TABLE STATISTICS\n==========================================================================="
puts connection.table_statistics.tableize(:leading_columns => ['table_name'])
puts "\n\n"

puts "TABLE SIZES\n==========================================================================="
puts connection.table_size.tableize(:leading_columns => ['table_name'])
puts "\n\n"

puts "DATABASE BLOAT\n==========================================================================="
puts connection.database_bloat.tableize(:leading_columns => ['table_name', 'index_name'])
puts "\n\n"

puts "TABLE BLOAT\n==========================================================================="
puts connection.table_bloat.tableize(:leading_columns => ['table_name'])
puts "\n\n"

puts "INDEX BLOAT\n==========================================================================="
puts connection.index_bloat.tableize(:leading_columns => ['table_name', 'index_name'])

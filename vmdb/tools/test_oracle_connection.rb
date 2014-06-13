if ARGV.length != 3
  puts "Error: Must pass database, username, and password as parameters."
  exit 1
end

$:.push File.join(File.dirname(__FILE__), '../../lib/db/MiqOracle/')
require 'rubygems'
require 'MiqOracle'
MiqOracle.test_connection(*ARGV)

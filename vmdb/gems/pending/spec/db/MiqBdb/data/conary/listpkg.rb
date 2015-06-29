#  listpkg.rb  -  This script will extract the package information
#  from a Conary database and list the installed packages and their
#  version numbers on the console.
#
#  Author:  Steven Oliphant
#           Stonecap Enterprises
#
#  This software is copyrighted 2007 All rights reserved
#  ManageIQ
#  1 International Boulevard
#  Mahwah, NJ   07495         
#
#  This version requires the sqlite 3 ruby interface library
#

begin
  require 'sqlite3'
rescue LoadError
  puts "sqlite3 library not found"
  exit
end

if ARGV.length == 0
  puts "No database name given"
  exit
end

begin
  fn = ARGV[0]
  fh = File.open fn
  fh.close
rescue
  puts fn+" cannot be opened"
  exit
end

begin 
  db =  SQLite3::Database.open fn
  columns = nil
  count = 0
  select = "select Instances.troveName, Instances.versionID,\
  Versions.version from Instances,Versions where\
  Instances.versionID = Versions.versionID and Instances.troveName\
  not like '%:%' and Instances.isPresent=1 order by Instances.troveName"
  db.execute2( select ) do |row|
    # skip first row - always the select name header
    if columns.nil?
      columns = row
    else
      count = count + 1
      # process row
      cnt = count.to_s 
      print  cnt, " Pkg: ", row[0], " Version ID: ", row[1], " Version: ", row[2], "\n"
    end
  end
rescue SQLite3::SQLException
  puts "SQL Query failed for database: "+fn
  exit  
end

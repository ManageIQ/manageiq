require 'test/unit'
require_relative '../MiqSqlite3'

class TestSqlite < Test::Unit::TestCase
	
	def test_btree
    fname = "#{File.dirname(__FILE__)}/conary.db"
puts "processing Database #{fname}"

		db = MiqSqlite3DB::MiqSqlite3.new(fname)
#puts "analyzing pages from 1 to #{db.npages}..."

#    puts "Table Names: "
#    db.table_names.each { |name| puts "#{name} "}
#    puts "\n"
    
    tVersions  = db.getTable("Versions")
    tInstances = db.getTable("Instances")
    
#    puts "Dumping Table Versions"
    versions = Hash.new
    tVersions.each_row { |row|
      id           = row['versionId']
      versions[id] = row['version']
    }
#    p versions
    
#    puts "Dumping Table Instances"
#    tInstances.dump
    troves = Hash.new
    tInstances.each_row { |row|
# p row      
      troveName = row['troveName']
      versionId = row['versionId']
      troves[troveName] = versionId if versions.has_key?(versionId) && !troveName.include?(":") && row['isPresent']
    }
    
    puts "#    troveName                      versionId   version"
    puts "---- ------------------------------ ----------  --------------------------------------------"
    
    count = 0
    troves.keys.sort.each { |t|
      versionId = troves[t]
      count += 1
      puts "#{'%3d' % count}: #{t.ljust(30)}\t#{versionId}\t#{versions[versionId]}"
    }
    
    
#    db.each_page { |page|
#      page.dump
#    }
		db.close
	end

end

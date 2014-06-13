require 'ostruct'
require 'test/unit'

$:.push("#{File.dirname(__FILE__)}/../../disk")
require 'MiqDisk'

$:.push("#{File.dirname(__FILE__)}/../../fs/iso9660")
require 'Iso9660BootSector'
require 'Iso9660DirectoryEntry'
require 'Iso9660Directory'
include Iso9660

class TestIso9660Directory < Test::Unit::TestCase
	
	def test_root_dir
		puts "Testing root dir."
		di = OpenStruct.new
		di.rawDisk = true
		di.fileName = $rawDisk
		dk = MiqDisk.getDisk(di)
		
		# Get an assumed boot sector at 32768.
		dk.seek(32768)
		bs = root = dir = names = nil
		assert_nothing_raised {bs = BootSector.new(dk)}
		assert_nothing_raised {root = DirectoryEntry.new(bs.rootEntry, bs.suff)}
		assert_nothing_raised {dir = Directory.new(bs, root)}
		assert_nothing_raised {names = dir.globNames}
		puts names
		dk.close
	end
	
end

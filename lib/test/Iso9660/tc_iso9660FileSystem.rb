require 'ostruct'
require 'test/unit'

$:.push("#{File.dirname(__FILE__)}/../../disk")
require 'MiqDisk'

$:.push("#{File.dirname(__FILE__)}/../../fs/MiqFS")
require 'MiqFS'

ONE_MEG = 0x0000100000

def readAll(fo)
	total = 0
	while buf = fo.read(ONE_MEG)
		total += buf.length
	end
	return total
end

def Dir(fs)
	names = fs.dirEntries(fs.pwd)
	names.each do |ent|
		next if ent == "." or ent == ".."
		if fs.fileFile?(ent)
			fs_len = nil
			assert_nothing_raised {fs_len = fs.fileSize(ent)}
			fo = nil
			assert_nothing_raised {fo = fs.fileOpen(ent)}
			fo_len = nil
			assert_nothing_raised {fo_len = fo.size}
			buf_len = nil
			assert_nothing_raised {buf_len = readAll(fo)}
			assert_equal(fs_len, fo_len)
			assert_equal(fs_len, buf_len)
			print "."
			fo.close
		end
	end
	
	# Recurse directories.
	names.each do |ent|
		next if ent == "." or ent == ".."
		if fs.fileDirectory?(ent) and not fs.fileSymLink?(ent)
			before = fs.pwd
			fs.chdir(ent)
			Dir(fs)
			fs.chdir(before)
		end
	end
end

class TestIso9660FileSystem < Test::Unit::TestCase
	
	def test_miq_fs
		puts "Testing file system"
		di = OpenStruct.new
		di.rawDisk = true
		di.fileName = $rawDisk
		dk = MiqDisk.getDisk(di)
		fs = nil
		assert_nothing_raised {fs = MiqFS.getFS(dk)}
		Dir(fs)
		dk.close
	end
	
end

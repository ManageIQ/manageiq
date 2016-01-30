require 'ostruct'
require 'minitest/unit'
require 'disk/MiqDisk'
require 'fs/iso9660/boot_sector'
require 'fs/iso9660/directory_entry'
require 'fs/iso9660/directory'
include Iso9660

class TestIso9660Directory < Minitest::Test
  def test_root_dir
    puts "Testing root dir."
    di = OpenStruct.new
    di.rawDisk = true
    di.fileName = $rawDisk
    dk = MiqDisk.getDisk(di)

    # Get an assumed boot sector at 32768.
    dk.seek(32768)
    bs = root = dir = names = nil
    assert_nothing_raised { bs = BootSector.new(dk) }
    assert_nothing_raised { root = DirectoryEntry.new(bs.rootEntry, bs.suff) }
    assert_nothing_raised { dir = Directory.new(bs, root) }
    assert_nothing_raised { names = dir.globNames }
    puts names
    dk.close
  end
end

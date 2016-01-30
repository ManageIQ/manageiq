require 'ostruct'
require 'minitest/unit'
require 'disk/MiqDisk'
require 'fs/iso9660/boot_sector'
include Iso9660

class TestIso9660BootSector < Minitest::Test
  def test_boot_sector
    puts "Testing boot sector"
    di = OpenStruct.new
    di.rawDisk = true
    di.fileName = $rawDisk
    dk = MiqDisk.getDisk(di)

    # Test an assumed boot sector at 32768.
    dk.seek(32768)
    bs = nil
    assert_nothing_raised { bs = BootSector.new(dk) }
    unless bs.nil?
      # Apparently this can vary, though I've never seen it do so.
      assert_equal(2048, bs.sectorSize)
      puts bs.dump
      puts "\n"
    end
    dk.close
  end
end

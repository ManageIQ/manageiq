require 'spec_helper'

$LOAD_PATH << lib_disk_dir

require 'ostruct'
require 'MiqDisk'
require 'modules/RawDisk'

describe RawDisk do
  before(:all) do
    init_logger
  end

  describe "#read" do
    around do |example|
      Camcorder.use_recording('rawdisk_read') do
        Camcorder.intercept MiqLargeFile::MiqLargeFileOther, :seek, :read
        Camcorder.intercept MiqLargeFile::MiqLargeFileStat,  :blockdev?

        disk_info = OpenStruct.new(:fileName => image_for('basic.img'))
        @disk     = MiqDisk.getDisk(disk_info, "RawDiskProbe")

        example.run
      end
    end

    it "returns specified number of bytes read from disk" do
      res  = @disk.read(10)
      res.should == Array.new(10) { 0 }.pack('C*')
    end
  end

  describe "#write" do
    around do |example|
      Camcorder.use_recording('rawdisk_write') do
        Camcorder.intercept MiqLargeFile::MiqLargeFileOther, :seek, :write
        Camcorder.intercept MiqLargeFile::MiqLargeFileStat,  :blockdev?

        disk_info = OpenStruct.new(:fileName  => image_for('basic.img'),
                                   :mountMode => 'rw')
        @disk     = MiqDisk.getDisk(disk_info, "RawDiskProbe")

        example.run
      end
    end

    it "writes specified number of bytes to disk" do
      res = @disk.write(Array.new(10) { 0 }, 10)
      res.should == 30
    end
  end
end # describe RawDisk

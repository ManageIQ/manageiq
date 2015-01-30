require 'spec_helper'

$LOAD_PATH << lib_disk_dir

require 'ostruct'
require 'MiqDisk'
require 'modules/RawDisk'
require 'modules/RawDiskProbe'
require 'modules/QcowDiskProbe'

describe MiqDisk do
  describe "#getDisk" do

    it "returns new matching disk instance" do
      disk_info = OpenStruct.new
      disk_info.fileName = ""

      disk = Object.new
      MiqDisk.should_receive(:new).with(RawDisk, disk_info, 0).and_return(disk)

      QcowDiskProbe.should_receive(:probe).with(disk_info).and_return(nil)
      RawDiskProbe.should_receive(:probe).with(disk_info).and_return("RawDisk")

      MiqDisk.getDisk(disk_info, %w(QcowDiskProbe RawDiskProbe)).should == disk
    end
  end

  describe "#discoverPartitions" do
    it "returns all dos partitions" do
      Camcorder.use_recording('dos_partitions') do
        Camcorder.intercept MiqLargeFile::MiqLargeFileOther, :seek, :read
        Camcorder.intercept MiqLargeFile::MiqLargeFileStat,  :blockdev?

        disk_info = OpenStruct.new(:fileName => image_for('dos2.img'))
        disk      = MiqDisk.getDisk(disk_info, "RawDiskProbe")
        disk.getPartitions.size.should == 5
      end
    end

    context "no dos partitions" do
      it "returns an empty array" do
        Camcorder.use_recording('no_partitions') do
          Camcorder.intercept MiqLargeFile::MiqLargeFileOther, :seek, :read
          Camcorder.intercept MiqLargeFile::MiqLargeFileStat,  :blockdev?

          disk_info = OpenStruct.new(:fileName => image_for('basic.img'))
          disk      = MiqDisk.getDisk(disk_info, "RawDiskProbe")
          disk.getPartitions.should be_empty
        end
      end
    end
  end
end

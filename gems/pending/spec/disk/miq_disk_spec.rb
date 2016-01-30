require 'ostruct'
require 'disk/MiqDisk'
require 'disk/modules/RawDisk'
require 'disk/modules/RawDiskProbe'
require 'disk/modules/QcowDiskProbe'

describe MiqDisk do
  describe ".getDisk" do
    it "returns new matching disk instance" do
      disk_info = OpenStruct.new
      disk_info.fileName = ""

      disk = Object.new
      expect(MiqDisk).to receive(:new).with(RawDisk, disk_info, 0).and_return(disk)

      expect(QcowDiskProbe).to receive(:probe).with(disk_info).and_return(nil)
      expect(RawDiskProbe).to receive(:probe).with(disk_info).and_return("RawDisk")

      expect(MiqDisk.getDisk(disk_info, %w(QcowDiskProbe RawDiskProbe))).to eq(disk)
    end
  end

  describe "#discoverPartitions" do
    it "with dos partitions" do
      Camcorder.use_recording('dos_partitions') do
        Camcorder.intercept MiqLargeFile::MiqLargeFileOther, :seek, :read
        Camcorder.intercept MiqLargeFile::MiqLargeFileStat,  :blockdev?

        disk_info = OpenStruct.new(:fileName => image_path('dos2.img'))
        disk      = MiqDisk.getDisk(disk_info, "RawDiskProbe")
        expect(disk.getPartitions.size).to eq(5)
      end
    end

    it "without dos partitions" do
      Camcorder.use_recording('no_partitions') do
        Camcorder.intercept MiqLargeFile::MiqLargeFileOther, :seek, :read
        Camcorder.intercept MiqLargeFile::MiqLargeFileStat,  :blockdev?

        disk_info = OpenStruct.new(:fileName => image_path('basic.img'))
        disk      = MiqDisk.getDisk(disk_info, "RawDiskProbe")
        expect(disk.getPartitions).to be_empty
      end
    end
  end
end

require 'spec_helper'

$LOAD_PATH << lib_disk_dir

require 'ostruct'
require 'MiqDisk'
require 'modules/RawDisk'
require 'modules/RawDiskProbe'
require 'modules/QcowDiskProbe'

describe MiqDisk do
  before(:all) do
    init_logger
  end

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

  describe "#pushFormatSupportForDisk" do
    it "returns new upstream disk"
    it "references specified downstream disk"
    it "sets upstream disk on specified disk"

    context "disk module not found" do
      it "returns specified disk"
    end
  end

  describe "#initialize" do
    it "sets disk module"
    it "sets disk info"
    it "sets partition type"
    it "sets partition number"

    context "no lba start/end" do
      describe "lbaStart" do
        it "is 0"
      end

      describe "lbaEnd" do
        it "is disk size"
      end
    end

    context "lba start specified, no lba end" do
      describe "lbaStart" do
        it "is specified value"
      end

      describe "lbaEnd" do
        it "is disk size"
      end
    end

    context "lba start and end specfied" do
      describe "lbaStart" do
        it "is specified value"
      end

      describe "lbaEnd" do
        it "is specified value + lbaStart"
      end
    end

    describe "startByteAddr" do
      it "equals lbaStart * blockSize"
    end

    describe "endByteAddr" do
      it "equals lbaEnd * blockSize"
    end

    describe "size" do
      it "equals endByteAddr - startByteAddr"
    end

    it "initializes seek to start of disk"
    
    context "partition 0 & not a base image" do
      it "sets disk signature"
    end

    context "hardwareId specified" do
      it "sets hwId"
    end
  end

  describe "#pushFormatSupport" do
    it "returns push format support for local disk"
  end

  describe "#diskSig" do
    it "initializes disk signature"
  end

  describe "#getPartitions" do
    it "discovers partitions"
  end

  describe "#seekPos" do
    it "returns current seek position - start byte address"
  end

  describe "#seek" do
    context "cur" do
      it "sets seek position to current position + specified amount"
    end

    context "end" do
      it "sets seek position to end byte address + specified amount"
    end

    context "set" do
      it "sets seek position to start byte + specified amount"
    end
  end

  describe "#read" do
    it "reads and returns len bytes from current seek position on disk"
    it "increments seek pos by number of bytes read"
  end

  describe "#write" do
    it "writes buffer of specified length to current seek position on disk"
    it "increments seek pos by number of bytes in buffer written"
  end

  describe "#close" do
    it "closes all partitions"
    it "closes disk"
  end

  describe "#getDiskSig" do
    it "reads and returns signature from disk bytes"
    it "preserves seek position"
  end

  describe "#discoverPartitions" do
    it "reads dos signature from mbr"

    it "discovers primary dos partitions"

    context "dos signature not found" do
      it "returns an empty array"
    end

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

  describe "#discoverDosPriPartitions" do
    it "initializes partitions"
    it "iterates over dos partition entries"
    it "decodes dos partitions"
    it "adds MiqPartition instances to partitions"

    context "dynamic disk" do
      it "returns empty array"
    end

    context "chs / lba partition" do
      it "concats extended partitions to partitions array"
    end

    it "returns partitions"
  end

  describe "#discoverDosExtPartitions" do
    it "decodes dos partition"
    it "adds MiqPartition instance to array returned"
    it "adds additional extended parititons to array returned"
  end
end

describe MiqPartition do
  describe "#initialize" do
    it "sets base disk"
  end

  describe "#d_init" do
    it "sets block size"
  end

  describe "#d_read" do
    it "reads from base disk"
  end

  describe "#d_write" do
    it "writes to base disk"
  end

  describe "#d_size" do
    it "raises an exception"
  end

  describe "#d_close" do
    it "is a noop"
  end
end

require 'spec_helper'

$LOAD_PATH << lib_disk_dir

require 'ostruct'
require 'MiqDisk'
require 'modules/RawDisk'
require 'modules/RawDiskProbe'
require 'modules/QcowDiskProbe'

describe MiqDisk do
  let(:dInfo) { OpenStruct.new }
  let(:disk)  { described_class.new(TestDisk, dInfo, 0) }

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
    context "disk module found" do
      before do
        DiskProbe.should_receive(:getDiskModForDisk)
                 .with(disk, nil).and_return(TestDisk)
      end

      it "returns new upstream disk" do
        d = MiqDisk.pushFormatSupportForDisk(disk)
        d.should be_an_instance_of(MiqDisk)
        d.should_not eq(disk)
      end

      it "references specified downstream disk" do
        d = MiqDisk.pushFormatSupportForDisk(disk)
        d.dInfo.downstreamDisk.should == disk
      end

      it "sets upstream disk on specified disk" do
        d = MiqDisk.pushFormatSupportForDisk(disk)
        disk.dInfo.upstreamDisk.should == d
      end
    end

    context "disk module not found" do
      before do
        DiskProbe.should_receive(:getDiskModForDisk).and_return(nil)
      end

      it "returns specified disk" do
        MiqDisk.pushFormatSupportForDisk(disk).should == disk
      end
    end
  end

  describe "#initialize" do
    it "sets disk module" do
      disk.instance_variable_get(:@dModule).should == TestDisk
    end

    it "sets disk info" do
      disk.dInfo.should == dInfo
    end

    it "sets partition type" do
      disk.partType.should == 0
    end

    it "sets partition number" do
      described_class.new(TestDisk, dInfo, 0, 0, 1, 2).partNum.should == 2
      described_class.new(TestDisk, dInfo, 0, 0, 1).partNum.should == 0
      described_class.new(TestDisk, dInfo, 0).partNum.should == 0
    end

    it "invokes d_init" do
      described_class.test_new(TestDisk, dInfo, 0) do |d|
        d.blockSize = 512
        d.should_receive(:d_init)
      end
    end

    context "no lba start/end" do
      describe "lbaStart" do
        it "is 0" do
          disk.lbaStart.should == 0
        end
      end

      describe "lbaEnd" do
        it "is disk size" do
          disk.lbaEnd.should == disk.d_size
        end
      end
    end

    context "lba start specified, no lba end" do
      let(:disk) { described_class.new(TestDisk, dInfo, 0, 512) }

      describe "lbaStart" do
        it "is specified value" do
          disk.lbaStart.should == 512
        end
      end

      describe "lbaEnd" do
        it "is disk size" do
          disk.lbaEnd.should == disk.d_size
        end
      end
    end

    context "lba start and end specfied" do
      let(:disk) { described_class.new(TestDisk, dInfo, 0, 512, 512) }

      describe "lbaStart" do
        it "is specified value" do
          disk.lbaStart.should == 512
        end
      end

      describe "lbaEnd" do
        it "is specified value + lbaStart" do
          disk.lbaEnd.should == 1024
        end
      end
    end

    describe "startByteAddr" do
      it "equals lbaStart * blockSize" do
        disk = described_class.new(TestDisk, dInfo, 0, 512);
        disk.startByteAddr.should == disk.lbaStart * disk.blockSize
      end
    end

    describe "endByteAddr" do
      it "equals lbaEnd * blockSize" do
        disk = described_class.new(TestDisk, dInfo, 0, 512, 1024);
        disk.endByteAddr.should == disk.lbaEnd * disk.blockSize
      end
    end

    describe "size" do
      it "equals endByteAddr - startByteAddr" do
        disk = described_class.new(TestDisk, dInfo, 0, 1024, 2048);
        disk.size.should == disk.endByteAddr - disk.startByteAddr
      end
    end

    it "initializes seek to start of disk" do
      disk.seekPos.should == 0
    end
    
    context "partition 0 & not a base image" do
      it "sets disk signature" do
        described_class.test_new(TestDisk, dInfo, 0) do |d|
          d.should_receive(:getDiskSig).and_return("disk sig")
        end
        dInfo.diskSig.should == "disk sig"
      end
    end

    context "hardwareId specified" do
      it "sets hwId" do
        dInfo.hardwareId = "hw123"
        described_class.new(TestDisk, dInfo, 0).hwId.should == "hw123:0"
      end
    end
  end

  describe "#pushFormatSupport" do
    it "returns push format support for local disk" do
      d = described_class.new(TestDisk, dInfo, 0)
      described_class.should_receive(:pushFormatSupportForDisk)
                     .with(disk).and_return(d)
      disk.pushFormatSupport.should == d
    end
  end

  describe "#diskSig" do
    it "initializes disk signature" do
      dInfo.baseOnly = true
      d = described_class.new TestDisk, dInfo, 0
      d.should_receive(:getDiskSig).once.and_return('disk sig')
      d.diskSig.should == 'disk sig'
      d.diskSig.should == 'disk sig'
      dInfo.diskSig.should == 'disk sig'
    end
  end

  describe "#getPartitions" do
    it "discovers partitions" do
      disk.should_receive(:discoverPartitions).and_return('partitions')
      disk.getPartitions.should == 'partitions'
    end
  end

  describe "#seekPos" do
    it "returns current seek position - start byte address" do
      disk.instance_variable_set(:@seekPos, 100)
      disk.instance_variable_set(:@startByteAddr, 25)
      disk.seekPos.should == 75
    end
  end

  describe "#seek" do
    before do
      disk.instance_variable_set(:@seekPos, 42)
      disk.instance_variable_set(:@startByteAddr, 0)
      disk.instance_variable_set(:@endByteAddr, 100)
    end

    context "cur" do
      it "sets seek position to current position + specified amount" do
        disk.seek 10, IO::SEEK_CUR
        disk.seekPos.should == 52
      end
    end

    context "end" do
      it "sets seek position to end byte address + specified amount" do
        disk.seek -10, IO::SEEK_END
        disk.seekPos.should == 90
      end
    end

    context "set" do
      it "sets seek position to start byte + specified amount" do
        disk.seek 22, IO::SEEK_SET
        disk.seekPos.should == 22
      end
    end

    it "defaults to set" do
      disk.seek 49
      disk.seekPos.should == 49
    end
  end

  describe "#read" do
    it "reads and returns len bytes from current seek position on disk" do
      disk.should_receive(:d_read).with(disk.seekPos, 10).and_return("abc")
      disk.read(10).should == "abc"
    end

    it "increments seek pos by number of bytes read" do
      disk.should_receive(:d_read).and_return("test")
      expect { disk.read(10) }.to change { disk.seekPos }.by(4)
    end
  end

  describe "#write" do
    it "writes buffer of specified length to current seek position on disk" do
      buf = []
      disk.should_receive(:d_write).with(disk.seekPos, buf, 10).and_return(5)
      disk.write(buf, 10).should == 5
    end

    it "increments seek pos by number of bytes in buffer written" do
      buf = []
      disk.should_receive(:d_write).and_return(3)
      expect { disk.write(buf, 10) }.to change { disk.seekPos }.by(3)
    end
  end

  describe "#close" do
    it "closes all partitions" do
      partition = Object.new
      partition.should_receive(:close)
      disk.instance_variable_set(:@partitions, [partition])
      disk.close
    end

    it "resets partitions" do
      disk.close
      disk.instance_variable_get(:@partitions).should be_nil
    end

    it "closes disk" do
      disk.should_receive(:d_close)
      disk.close
    end
  end

  describe "#getDiskSig" do
    it "reads and returns signature from disk bytes" do
      disk.should_receive(:seek)
          .with(described_class::DISK_SIG_OFFSET, IO::SEEK_SET)
      disk.should_receive(:read)
          .with(described_class::DISK_SIG_SIZE).and_return("90\x00\x00")
      disk.should_receive(:seek)
      disk.send(:getDiskSig).should == 12345
    end

    it "preserves seek position" do
      expect { disk.send(:getDiskSig) }.to_not change { disk.seekPos }
    end
  end

  describe "#discoverPartitions" do
    it "reads dos signature from mbr" do
      disk.should_receive(:seek)
          .with(0, IO::SEEK_SET)
      disk.should_receive(:read)
          .with(described_class::MBR_SIZE).and_return("")
      disk.send(:discoverPartitions)
    end

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

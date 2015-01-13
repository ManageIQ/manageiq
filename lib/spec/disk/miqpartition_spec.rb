require 'spec_helper'

$LOAD_PATH << lib_disk_dir

require 'ostruct'
require 'MiqPartition'

describe MiqPartition do
  let(:dInfo) { OpenStruct.new }
  let(:disk)  { MiqDisk.new(TestDisk, dInfo, 0) }
  let(:partition) { described_class.new disk, 42, 100, 200, 1 }

  before(:all) do
    init_logger
  end

  describe "#initialize" do
    it "sets base disk" do
      partition.instance_variable_get(:@baseDisk).should == disk
      partition.dInfo.should == dInfo
    end
  end

  describe "#d_init" do
    it "sets block size" do
      partition.d_init
      partition.blockSize.should == disk.blockSize
    end
  end

  describe "#d_read" do
    it "reads from base disk" do
      disk.should_receive(:d_read).with(10, 20)
      partition.d_read(10, 20)
    end
  end

  describe "#d_write" do
    it "writes to base disk" do
      buf = []
      disk.should_receive(:d_write).with(1, buf, 42)
      partition.d_write(1, buf, 42)
    end
  end

  describe "#d_size" do
    it "raises an exception" do
      expect { partition.d_size }.to raise_error
    end
  end

  #describe "#d_close" do
    #it "is a noop"
  #end
end

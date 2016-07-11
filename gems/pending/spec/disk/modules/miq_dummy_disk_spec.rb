require 'ostruct'
require 'disk/modules/miq_dummy_disk'

describe MiqDummyDisk do
  DUMMY_DISK_BLOCKS    = 1000
  DUMMY_DISK_BLOCKSIZE = 4096

  context ".new" do
    it "should not raise an error with arguments" do
      expect do
        d_info            = OpenStruct.new
        d_info.d_size     = DUMMY_DISK_BLOCKS
        d_info.block_size = DUMMY_DISK_BLOCKSIZE
        MiqDummyDisk.new(d_info)
      end.not_to raise_error
    end

    it "should not raise an error without arguments" do
      expect do
        MiqDummyDisk.new
      end.not_to raise_error
    end

    it "should return an MiqDisk object without arguments" do
      dummy_disk = MiqDummyDisk.new
      expect(dummy_disk).to be_kind_of(MiqDisk)
    end

    it "should return an MiqDisk object with arguments" do
      d_info            = OpenStruct.new
      d_info.d_size     = DUMMY_DISK_BLOCKS
      d_info.block_size = DUMMY_DISK_BLOCKSIZE
      dummy_disk = MiqDummyDisk.new(d_info)
      expect(dummy_disk).to be_kind_of(MiqDisk)
    end
  end

  context "Instance methods" do
    before do
      d_info           = OpenStruct.new
      d_info.d_size    = DUMMY_DISK_BLOCKS
      d_info.block_size = DUMMY_DISK_BLOCKSIZE
      @dummy_disk = MiqDummyDisk.new(d_info)
    end

    describe "#d_size" do
      it "should return the expected dummy disk size" do
        expect(@dummy_disk.d_size).to eq(DUMMY_DISK_BLOCKS)
      end
    end

    describe "#blockSize" do
      it "should return the expected dummy disk block size" do
        expect(@dummy_disk.blockSize).to eq(DUMMY_DISK_BLOCKSIZE)
      end
    end

    describe "#size" do
      it "should return the size of the dummy disk in bytes" do
        expect(@dummy_disk.size).to eq(DUMMY_DISK_BLOCKS * DUMMY_DISK_BLOCKSIZE)
      end
    end

    describe "#lbaStart" do
      it "should return the expected start logical block address" do
        expect(@dummy_disk.lbaStart).to eq(0)
      end
    end

    describe "#lbaEnd" do
      it "should return the expected end logical block address" do
        expect(@dummy_disk.lbaEnd).to eq(DUMMY_DISK_BLOCKS)
      end
    end

    describe "#startByteAddr" do
      it "should return the expected start byte address" do
        expect(@dummy_disk.startByteAddr).to eq(0)
      end
    end

    describe "#d_write" do
      before do
        @dummy_string = "12345"
      end

      it "should return a dummy string" do
        expect(@dummy_disk.d_write(0, @dummy_string, @dummy_string.length)).to eq(@dummy_string.length)
      end
    end

    describe "#endByteAddr" do
      it "should return the expected end byte address" do
        expect(@dummy_disk.endByteAddr).to eq(DUMMY_DISK_BLOCKS * DUMMY_DISK_BLOCKSIZE)
      end

      it "should return a value consistent with the other values" do
        expect(@dummy_disk.endByteAddr).to eq(@dummy_disk.startByteAddr + @dummy_disk.lbaEnd * @dummy_disk.blockSize)
      end
    end

    describe "#getPartitions" do
      it "should return an array" do
        expect(@dummy_disk.getPartitions).to be_kind_of(Array)
      end

      it "should not return any partitions" do
        parts = @dummy_disk.getPartitions
        expect(parts.length).to eq(0)
      end
    end
  end
end

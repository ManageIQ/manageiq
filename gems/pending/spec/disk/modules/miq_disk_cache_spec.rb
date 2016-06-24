require 'ostruct'
require 'disk/modules/miq_disk_cache'
require 'disk/modules/miq_dummy_disk'

describe MiqDiskCache do
  DUMMY_BLOCKS    = 1000
  DUMMY_BLOCKSIZE = 4096
  before do
    dummy_info            = OpenStruct.new
    dummy_info.d_size     = DUMMY_BLOCKS
    dummy_info.block_size = DUMMY_BLOCKSIZE
    @dummy_disk           = MiqDummyDisk.new(dummy_info)
  end

  context ".new" do
    it "should raise an error, given a bad downstream module" do
      expect do
        MiqDiskCache.new(nil)
      end.to raise_error(RuntimeError)
    end

    it "should return an MiqDisk object" do
      miq_cache = MiqDiskCache.new(@dummy_disk)
      expect(miq_cache).to be_kind_of(MiqDisk)
    end
  end

  context "Instance methods" do
    before do
      @miq_cache = MiqDiskCache.new(@dummy_disk, 200, 32)
    end

    describe "#d_size" do
      it "should return the expected disk cache size" do
        expect(@miq_cache.d_size).to eq(DUMMY_BLOCKS)
      end
    end

    describe "#blockSize" do
      it "should return the expected disk cache block size" do
        expect(@miq_cache.blockSize).to eq(DUMMY_BLOCKSIZE)
      end
    end

    describe "#size" do
      it "should return the size of the downstream disk in bytes" do
        expect(@miq_cache.size).to eq(DUMMY_BLOCKS * DUMMY_BLOCKSIZE)
      end
    end

    describe "#lbaStart" do
      it "should return the expected start logical block address" do
        expect(@miq_cache.lbaStart).to eq(0)
      end
    end

    describe "#lbaEnd" do
      it "should return the expected end logical block address" do
        expect(@miq_cache.lbaEnd).to eq(DUMMY_BLOCKS)
      end
    end

    describe "#startByteAddr" do
      it "should return the expected start byte address" do
        expect(@miq_cache.startByteAddr).to eq(0)
      end
    end

    describe "#d_write" do
      it "should return a dummy string" do
        expect(@miq_cache.d_write(0, "12345", 5)).to eq("MiqDummyDisk.d_write")
      end
    end

    describe "#endByteAddr" do
      it "should return the expected end byte address" do
        expect(@miq_cache.endByteAddr).to eq(DUMMY_BLOCKS * DUMMY_BLOCKSIZE)
      end

      it "should return a value consistent with the other values" do
        expect(@miq_cache.endByteAddr).to eq(@miq_cache.startByteAddr + @miq_cache.lbaEnd * @miq_cache.blockSize)
      end
    end

    describe "#getPartitions" do
      it "should return an array" do
        expect(@miq_cache.getPartitions).to be_kind_of(Array)
      end

      it "should not return any partitions" do
        parts = @miq_cache.getPartitions
        expect(parts.length).to eq(0)
      end
    end
  end
  context "Caching Stats" do
    before do
      @lru_hash_entries      = 200
      @min_sectors_per_entry = 32
      @miq_cache            = MiqDiskCache.new(@dummy_disk, @lru_hash_entries, @min_sectors_per_entry)
      @start_hits           = @miq_cache.cache_hits.values.reduce(:+)
      @start_hits           = @start_hits.nil? ? 0 : @start_hits
      @start_misses         = @miq_cache.cache_misses.values.reduce(:+)
      @start_misses         = @start_misses.nil? ? 0 : @start_misses
      (@min_sectors_per_entry..(2 * @min_sectors_per_entry - 1)).each do |block|
        @miq_cache.d_read(block * DUMMY_BLOCKSIZE, DUMMY_BLOCKSIZE)
      end
    end
    it "should read from the cache repeatedly" do
      hits = @miq_cache.cache_hits.values.reduce(:+)
      expect(hits).to eq(@min_sectors_per_entry - 1 + @start_hits)
    end
    it "should read once from the underlying disk" do
      misses = @miq_cache.cache_misses.values.reduce(:+)
      expect(misses).to eq(1 + @start_misses)
    end
  end
end

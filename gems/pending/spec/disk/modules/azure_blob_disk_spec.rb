require 'ostruct'
require 'azure-armrest'
require 'disk/modules/AzureBlobDisk'
require 'vcr'

describe AzureBlobDisk do
  before(:all) do
    @test_env = TestEnvHelper.new(__FILE__)
    @test_env.vcr_filter

    @client_id     = @test_env[:azure_client_id]
    @client_key    = @test_env[:azure_client_key]
    @tenant_id     = @test_env[:azure_tenant_id]
    @blob_uri      = @test_env[:blob_uri]

    @test_env.ensure_recording_dir_exists
  end

  before(:each) do |example|
    Azure::Armrest::ArmrestService.clear_caches
    example_id = "#{example.example_group.description}-#{example.metadata[:ex_tag]}"
    cassette_name = @test_env.cassette_for(example_id)
    VCR.insert_cassette(cassette_name, :decode_compressed_response => true)

    @azure_config = Azure::Armrest::ArmrestService.configure(
      :client_id  => @client_id,
      :client_key => @client_key,
      :tenant_id  => @tenant_id
    )

    @storage_account_service = Azure::Armrest::StorageAccountService.new(@azure_config)
  end

  after(:each) do
    VCR.eject_cassette
  end

  describe ".new" do
    it "should raise an error, given a bad blob uri", :ex_tag => 1 do
      expect do
        AzureBlobDisk.new(@storage_account_service, "https://bad.blob.uri/and/path")
      end.to raise_error(RuntimeError)
    end

    it "should return an MiqDisk object", :ex_tag => 2 do
      miq_disk = AzureBlobDisk.new(@storage_account_service, @blob_uri)
      expect(miq_disk).to be_kind_of(MiqDisk)
    end
  end

  describe "Instance methods" do
    before(:each) do
      @miq_disk = AzureBlobDisk.new(@storage_account_service, @blob_uri)
    end

    describe "#diskType" do
      it "should return the expected disk type", :ex_tag => 1 do
        expect(@miq_disk.diskType).to eq("azure-blob")
      end
    end

    describe "#partType" do
      it "should return the expected partition type", :ex_tag => 1 do
        expect(@miq_disk.partType).to eq(0)
      end
    end

    describe "#partNum" do
      it "should return 0 for the whole disk", :ex_tag => 1 do
        expect(@miq_disk.partNum).to eq(0)
      end
    end

    describe "#blockSize" do
      it "should return the expected block size", :ex_tag => 1 do
        expect(@miq_disk.blockSize).to eq(512)
      end
    end

    describe "#size" do
      it "should return the size of the disk in bytes", :ex_tag => 1 do
        expect(@miq_disk.size).to eq(16_492_674_678_784)
      end
    end

    describe "#lbaStart" do
      it "should return the expected start logical block address", :ex_tag => 1 do
        expect(@miq_disk.lbaStart).to eq(0)
      end
    end

    describe "#lbaEnd" do
      it "should return the expected end logical block address", :ex_tag => 1 do
        expect(@miq_disk.lbaEnd).to eq(32_212_255_232)
      end
    end

    describe "#startByteAddr" do
      it "should return the expected start byte address", :ex_tag => 1 do
        expect(@miq_disk.startByteAddr).to eq(0)
      end
    end

    describe "#endByteAddr" do
      it "should return the expected end byte address", :ex_tag => 1 do
        expect(@miq_disk.endByteAddr).to eq(16_492_674_678_784)
      end

      it "should return a value consistent with the other values", :ex_tag => 2 do
        expect(@miq_disk.endByteAddr).to eq(@miq_disk.startByteAddr + @miq_disk.lbaEnd * @miq_disk.blockSize)
      end
    end

    describe "#getPartitions" do
      it "should reurn an array", :ex_tag => 1 do
        expect(@miq_disk.getPartitions).to be_kind_of(Array)
      end

      it "should return the expected number of partitions", :ex_tag => 1 do
        parts = @miq_disk.getPartitions
        expect(parts.length).to eq(3)
      end

      it "should return instances of MiqPartition", :ex_tag => 1 do
        parts = @miq_disk.getPartitions
        parts.each do |p|
          expect(p).to be_kind_of(MiqPartition)
        end
      end

      it "partition info should be consistent with the parent disk", :ex_tag => 1 do
        parts = @miq_disk.getPartitions
        parts.each do |p|
          expect(p.partNum).to_not eq(0)
          expect(p.size).to be < @miq_disk.size

          expect(p.lbaStart).to be > @miq_disk.lbaStart
          expect(p.lbaStart).to be < @miq_disk.lbaEnd

          expect(p.lbaEnd).to be > @miq_disk.lbaStart
          expect(p.lbaEnd).to be < @miq_disk.lbaEnd

          expect(p.startByteAddr).to be > @miq_disk.startByteAddr
          expect(p.startByteAddr).to be < @miq_disk.endByteAddr

          expect(p.endByteAddr).to be > @miq_disk.startByteAddr
          expect(p.endByteAddr).to be < @miq_disk.endByteAddr
        end
      end
    end
  end
end

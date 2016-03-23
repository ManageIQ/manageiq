require_relative './miq_vm_instance_methods_shared_examples'
require 'ostruct'
require 'azure-armrest'
require 'MiqVm/miq_azure_vm'
require 'vcr'

describe MiqAzureVm do
  before(:all) do
    @test_env = TestEnvHelper.new(__FILE__)
    @test_env.vcr_filter

    @client_id  = @test_env[:azure_client_id]
    @client_key = @test_env[:azure_client_key]
    @tenant_id  = @test_env[:azure_tenant_id]
    @image_name = @test_env[:image_name]
    @image_uri  = @test_env[:image_uri]

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
  end

  after(:each) do
    VCR.eject_cassette
  end

  describe ".new" do
    it "should raise ArgumentError when args are not provided", :ex_tag => 1 do
      expect do
        MiqAzureVm.new(@azure_config)
      end.to raise_error(ArgumentError)
    end

    it "should raise ArgumentError when :name arg is not provided", :ex_tag => 2 do
      expect do
        MiqAzureVm.new(@azure_config, :image_uri => @image_uri)
      end.to raise_error(ArgumentError)
    end

    it "should raise ArgumentError when :image_uri arg is not provided", :ex_tag => 3 do
      expect do
        MiqAzureVm.new(@azure_config, :name => @image_name)
      end.to raise_error(ArgumentError)
    end

    it "should return an MiqAzureVm object", :ex_tag => 4 do
      azure_vm = MiqAzureVm.new(@azure_config, :name => @image_name, :image_uri => @image_uri)
      expect(azure_vm).to be_kind_of(MiqAzureVm)
    end
  end

  describe "Instance methods" do
    before(:each) do
      @azure_vm = MiqAzureVm.new(@azure_config, :name => @image_name, :image_uri => @image_uri)
    end

    after(:each) do
      @azure_vm.unmount
    end

    it_behaves_like "MiqVm instance methods" do
      let(:miq_vm)                { @azure_vm }
      let(:expected_num_roots)    { 1 }
      let(:expected_guest_os)     { "Windows" }
      let(:expected_num_fs)       { 1 }
      let(:expected_num_fs_types) { ["NTFS"] }
      let(:expected_mount_points) { ["C:"] }
    end
  end
end

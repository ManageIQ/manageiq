describe MiqRegion do
  context "after seeding" do
    before(:each) do
      MiqRegion.seed
    end

    it "should increment naming sequence number after each call" do
      expect(MiqRegion.my_region.next_naming_sequence("namingtest$n{3}", "naming")).to eq(1)
      expect(MiqRegion.my_region.next_naming_sequence("namingtest$n{3}", "naming")).to eq(2)
      expect(MiqRegion.my_region.next_naming_sequence("anothertest$n{3}", "naming")).to eq(1)
      expect(MiqRegion.my_region.next_naming_sequence("anothertest$n{3}", "naming")).to eq(2)
    end

    context "with cloud and infra EMSes" do
      before :each do
        _, _, zone = EvmSpecHelper.create_guid_miq_server_zone
        ems_vmware = FactoryGirl.create(:ems_vmware, :zone => zone)
        ems_openstack = FactoryGirl.create(:ems_openstack, :zone => zone)
        ems_redhat = FactoryGirl.create(:ems_redhat, :zone => zone)

        @ems_clouds = [ems_openstack]
        @ems_infras = [ems_redhat, ems_vmware]

        @region = MiqRegion.my_region
      end

      it "should be able to return the list of ems_clouds" do
        expect(@region.ems_clouds).to include(*@ems_clouds)
        expect(@region.ems_clouds).not_to include(*@ems_infras)
      end

      it "should be able to return the list of ems_infras" do
        expect(@region.ems_infras).to include(*@ems_infras)
        expect(@region.ems_infras).not_to include(*@ems_clouds)
      end
    end
  end

  it ".log_not_under_management" do
    MiqRegion.seed
    FactoryGirl.create(:host_vmware)
    FactoryGirl.create(:vm_vmware)
    expect($log).to receive(:info).with(/VMs: \[1\], Hosts: \[1\]/)
    described_class.log_not_under_management("")
  end

  context ".seed" do
    before do
      @region_number = 99
      allow(MiqRegion).to receive_messages(:my_region_number => @region_number)
      MiqRegion.seed
    end

    include_examples ".seed called multiple times"

    it "should have the expected region number" do
      expect(MiqRegion.first.region).to eq(@region_number)
    end

    it "replaces deleted current region" do
      MiqRegion.where(:region => @region_number).destroy_all
      expect(MiqRegion.count).to eq(0)
      MiqRegion.seed
      expect(MiqRegion.first.region).to eq(@region_number)
    end

    it "raises Exception if db region_id doesn't match my_region_number" do
      @db = FactoryGirl.create(:miq_database)
      allow(MiqRegion).to receive_messages(:my_region_number => @region_number + 1)
      expect { MiqRegion.seed }.to raise_error(Exception)
    end
  end

  describe ".replication_type" do
    it "returns :global when configured as a pglogical subscriber" do
      pgl = double(:provider? => false, :subscriber? => true, :node? => true)
      allow(MiqPglogical).to receive(:new).and_return(pgl)

      expect(described_class.replication_type).to eq(:global)
    end

    it "returns :remote when configured as a pglogical provider" do
      pgl = double(:provider? => true, :subscriber? => false, :node? => true)
      allow(MiqPglogical).to receive(:new).and_return(pgl)

      expect(described_class.replication_type).to eq(:remote)
    end

    it "returns :none if pglogical is not configured" do
      pgl = double(:provider? => false, :subscriber? => false, :node? => false)
      allow(MiqPglogical).to receive(:new).and_return(pgl)

      expect(described_class.replication_type).to eq(:none)
    end
  end

  describe ".replication_type=" do
    it "returns the replication_type, even when unchanged" do
      pgl = double(:provider? => true, :subscriber? => false, :node? => true)
      allow(MiqPglogical).to receive(:new).and_return(pgl)
      expect(described_class.replication_type = :remote).to eq :remote
    end

    it "destroys the provider when transition is :remote -> :none" do
      pgl = double(:provider? => true, :subscriber? => false, :node? => true)
      allow(MiqPglogical).to receive(:new).and_return(pgl)

      expect(pgl).to receive(:destroy_provider)

      expect(described_class.replication_type = :none).to eq :none
    end

    it "deletes all subscriptions when transition is :global -> :none" do
      pgl = double(:provider? => false, :subscriber? => true, :node? => true)
      allow(MiqPglogical).to receive(:new).and_return(pgl)

      expect(PglogicalSubscription).to receive(:delete_all)

      expect(described_class.replication_type = :none).to eq :none
    end

    it "creates a new provider when transition is :none -> :remote" do
      pgl = double(:provider? => false, :subscriber? => false, :node? => false)
      allow(MiqPglogical).to receive(:new).and_return(pgl)

      expect(pgl).to receive(:configure_provider)

      expect(described_class.replication_type = :remote).to eq :remote
    end

    it "deletes all subscriptions and creates a new provider when transition is :global -> :remote" do
      pgl = double(:provider? => false, :subscriber? => true, :node? => true)
      allow(MiqPglogical).to receive(:new).and_return(pgl)

      expect(PglogicalSubscription).to receive(:delete_all)
      expect(pgl).to receive(:configure_provider)

      expect(described_class.replication_type = :remote).to eq :remote
    end

    it "destroys the provider when transition is :remote -> :global" do
      pgl = double(:provider? => true, :subscriber? => false, :node? => true)
      allow(MiqPglogical).to receive(:new).and_return(pgl)

      expect(pgl).to receive(:destroy_provider)

      expect(described_class.replication_type = :global).to eq :global
    end
  end

  describe "#generate_auth_key" do
    let(:remote_region) { FactoryGirl.create(:miq_region) }
    let(:remote_key)    { "this is the encryption key!" }

    before { EvmSpecHelper.create_guid_miq_server_zone }

    it "stores an authentication key" do
      require 'net/scp'
      host     = "remote-region.example.com"
      password = "mypassword"
      user     = "admin"

      expect(Net::SCP).to receive(:download!)
        .with(host, user, "/var/www/miq/vmdb/certs/v2_key", nil, :ssh => {:password => password})
        .and_return(remote_key)

      remote_region.generate_auth_key(user, password, host)

      expect(remote_region.authentication_token("system_api")).to eq(remote_key)
    end
  end

  describe "#auth_key_configured?" do
    let(:remote_region) { FactoryGirl.create(:miq_region) }
    let(:remote_key)    { "this is the encryption key!" }

    before { EvmSpecHelper.create_guid_miq_server_zone }

    it "returns true if a key is configured" do
      FactoryGirl.create(
        :auth_token,
        :resource_id   => remote_region.id,
        :resource_type => "MiqRegion",
        :auth_key      => remote_key
      )

      expect(remote_region.auth_key_configured?).to be true
    end

    it "returns false if a key is not configured" do
      expect(remote_region.auth_key_configured?).to be false
    end
  end

  describe "#remove_auth_key" do
    let(:remote_region) { FactoryGirl.create(:miq_region) }
    let(:remote_key)    { "this is the encryption key!" }

    before { EvmSpecHelper.create_guid_miq_server_zone }

    it "removes a key if configured" do
      FactoryGirl.create(
        :auth_token,
        :resource_id   => remote_region.id,
        :resource_type => "MiqRegion",
        :auth_key      => remote_key,
        :authtype      => "system_api"
      )
      expect(remote_region.auth_key_configured?).to be true
      remote_region.remove_auth_key
      remote_region.reload
      expect(remote_region.auth_key_configured?).to be false
    end
  end

  describe "#api_system_auth_token" do
    let(:region) { FactoryGirl.create(:miq_region, :region => ApplicationRecord.my_region_number) }

    it "generates the token correctly" do
      user = "admin"
      server = FactoryGirl.create(:miq_server, :has_active_webservices => true)
      expect(region).to receive(:authentication_token).and_return(File.read(Rails.root.join("certs/v2_key")))

      token = region.api_system_auth_token(user)
      token_hash = YAML.load(MiqPassword.decrypt(token))

      expect(token_hash[:server_guid]).to eq(server.guid)
      expect(token_hash[:userid]).to eq(user)
      expect(token_hash[:timestamp]).to be > 5.minutes.ago.utc
    end
  end

  describe "#required_credential_fields" do
    let(:region) { FactoryGirl.create(:miq_region, :region => ApplicationRecord.my_region_number) }

    it "checks the right credential fields" do
      expect(region.required_credential_fields(:system_api)).to eq([:auth_key])
    end
  end

  context "ConfigurationManagementMixin" do
    let(:region) { FactoryGirl.create(:miq_region, :region => ApplicationRecord.my_region_number) }

    describe "#settings_for_resource" do
      it "returns the resource's settings" do
        settings = {:some_thing => [1, 2, 3]}
        stub_settings(settings)
        expect(region.settings_for_resource.to_hash).to eq(settings)
      end
    end

    describe "#add_settings_for_resource" do
      it "sets the specified settings" do
        settings = {:some_test_setting => {:setting => 1}}
        expect(region).to receive(:reload_all_server_settings)

        region.add_settings_for_resource(settings)

        expect(Vmdb::Settings.for_resource(region).some_test_setting.setting).to eq(1)
      end
    end

    describe "#reload_all_server_settings" do
      let(:external_region_id) do
        remote_region_number = ApplicationRecord.my_region_number + 1
        ApplicationRecord.region_to_range(remote_region_number).first
      end

      it "queues #reload_settings for the started servers" do
        started_server = FactoryGirl.create(:miq_server, :status => "started")
        FactoryGirl.create(:miq_server, :status => "started", :id => external_region_id)
        FactoryGirl.create(:miq_server, :status => "stopped")

        region.reload_all_server_settings

        expect(MiqQueue.count).to eq(1)
        message = MiqQueue.first
        expect(message.instance_id).to eq(started_server.id)
        expect(message.method_name).to eq("reload_settings")
      end
    end
  end
end

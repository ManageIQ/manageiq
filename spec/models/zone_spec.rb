describe Zone do
  include_examples ".seed called multiple times"

  context "with two small envs" do
    before(:each) do
      @zone1 = FactoryGirl.create(:small_environment)
      @host1 = @zone1.ext_management_systems.first.hosts.first
      @zone1.reload
      @zone2 = FactoryGirl.create(:small_environment)
      @host2 = @zone2.ext_management_systems.first.hosts.first
      @zone2.reload
    end

    it "zone1#hosts will return hosts in zone1" do
      expect(@zone1.hosts).to match_array([@host1])
    end

    it "zone2#hosts will return hosts in zone2" do
      expect(@zone2.hosts).to match_array([@host2])
    end

    it "zone1#vms will return vms in zone1" do
      expect(@zone1.vms).to match_array(@host1.vms)
    end

    it "zone2#vms will return vms in zone2" do
      expect(@zone2.vms).to match_array(@host2.vms)
    end

    it "hosts in virtual reflections" do
      expect(described_class.includes(:aggregate_cpu_speed)).not_to be_nil
    end

    it "vms_and_templates in virtual reflections" do
      expect(described_class.includes(:aggregate_vm_cpus)).not_to be_nil
    end
  end

  context "when dealing with clouds" do
    before :each do
      guid, server, @zone = EvmSpecHelper.create_guid_miq_server_zone
    end

    it "returns the set of ems_clouds" do
      ems_clouds = []
      2.times { ems_clouds << FactoryGirl.create(:ems_openstack, :zone => @zone) }
      2.times { ems_clouds << FactoryGirl.create(:ems_amazon, :zone => @zone) }
      ems_infra = FactoryGirl.create(:ems_vmware, :zone => @zone)

      zone_clouds = @zone.ems_clouds
      expect(zone_clouds).to match_array(ems_clouds)

      expect(zone_clouds).not_to include ems_infra
    end

    it "returns the set of availability_zones" do
      openstack = FactoryGirl.create(:ems_openstack, :zone => @zone)
      azs = []
      3.times { azs << FactoryGirl.create(:availability_zone, :ems_id => openstack.id) }

      expect(@zone.availability_zones).to match_array(azs)
    end
  end

  describe "#clustered_hosts" do
    let(:zone) { FactoryGirl.create(:zone) }
    let(:ems) { FactoryGirl.create(:ems_vmware, :zone => zone) }
    let(:cluster) { FactoryGirl.create(:ems_cluster, :ext_management_system => ems)}
    let(:host_with_cluster) { FactoryGirl.create(:host, :ext_management_system => ems, :ems_cluster => cluster) }
    let(:host) { FactoryGirl.create(:host, :ext_management_system => ems) }

    it "returns clustered hosts" do
      host ; host_with_cluster

      expect(zone.clustered_hosts).to eq([host_with_cluster])
    end
  end

  describe "#non_clustered_hosts" do
    let(:zone) { FactoryGirl.create(:zone) }
    let(:ems) { FactoryGirl.create(:ems_vmware, :zone => zone) }
    let(:cluster) { FactoryGirl.create(:ems_cluster, :ext_management_system => ems)}
    let(:host_with_cluster) { FactoryGirl.create(:host, :ext_management_system => ems, :ems_cluster => cluster) }
    let(:host) { FactoryGirl.create(:host, :ext_management_system => ems) }

    it "returns clustered hosts" do
      host ; host_with_cluster

      expect(zone.non_clustered_hosts).to eq([host])
    end
  end

  context ".determine_queue_zone" do
    subject           { described_class }

    before do
      allow(ServerRole).to receive_messages(:region_scoped_roles => [ServerRole.new(:name => "inregion")])
      allow(MiqServer).to receive(:my_zone) { "myzone" }
    end

    context "with no zone specified" do
      it "no role specified should return server zone" do
        expect(subject.determine_queue_zone({})).to eq("myzone")
      end

      it "regional role specified should return ANY zone" do
        expect(subject.determine_queue_zone(:role => "inregion")).to be_nil
      end

      it "non-regional role specified should return server zone" do
        expect(subject.determine_queue_zone(:role => "anyregion")).to eq("myzone")
      end
    end
    context "with zone specified" do
      it "should return specified zone" do
        expect(subject.determine_queue_zone(:zone => "special", :role => "inregion")).to eq("special")
      end

      it "should return specified zone (even if nil)" do
        expect(subject.determine_queue_zone(:zone => nil, :role => "inregion")).to be_nil
      end
    end
  end

  context "#active?" do
    let(:zone) { described_class.new(:miq_servers => [miq_server]) }
    let(:miq_server) { MiqServer.new }

    it "true" do
      allow(miq_server).to receive(:active?).and_return(true)

      expect(zone.active?).to be_truthy
    end

    it "false" do
      allow(miq_server).to receive(:active?).and_return(false)

      expect(zone.active?).to be_falsey
    end
  end

  context "#ntp_settings" do
    let(:zone) { described_class.new }

    it "no settings returns default NTP settings" do
      expect(zone.ntp_settings).to eq(:server => ["0.pool.ntp.org", "1.pool.ntp.org", "2.pool.ntp.org"])
    end

    it "with :ntp key returns what was set" do
      zone.settings[:ntp] = {:server => ["tock.example.com"]}

      expect(zone.ntp_settings).to eq(:server => ["tock.example.com"])
    end
  end

  context "#after_save callback" do
    before do
      _, _, @zone = EvmSpecHelper.create_guid_miq_server_zone

      @zone.update_attributes(:settings => {:ntp => {:server => ["tick.example.com"]}})
      MiqQueue.where(:class_name => "MiqServer", :method_name => "ntp_reload").destroy_all
    end

    it "settings changed queues ntp reload" do
      expect_any_instance_of(described_class).to receive(:queue_ntp_reload_if_changed).once.and_call_original

      @zone.update_attributes(:settings => {:ntp => {:server => ["tock.example.com"]}})

      expect(MiqQueue.where(:class_name => "MiqServer", :method_name => "ntp_reload").count).to eq(1)
    end

    it "settings not changed does not queue ntp reload" do
      expect_any_instance_of(described_class).to receive(:queue_ntp_reload_if_changed).once.and_call_original

      @zone.update_attributes(:settings => {:ntp => {:server => ["tick.example.com"]}})

      expect(MiqQueue.where(:class_name => "MiqServer", :method_name => "ntp_reload").count).to eq(0)
    end
  end

  it "#settings should always be a hash" do
    expect(described_class.new.settings).to be_kind_of(Hash)
  end

  context "ConfigurationManagementMixin" do
    let(:zone) { FactoryGirl.create(:zone) }

    describe "#settings_for_resource" do
      it "returns the resource's settings" do
        settings = {:some_thing => [1, 2, 3]}
        stub_settings(settings)
        expect(zone.settings_for_resource.to_hash).to eq(settings)
      end
    end

    describe "#add_settings_for_resource" do
      it "sets the specified settings" do
        settings = {:some_test_setting => {:setting => 1}}
        expect(zone).to receive(:reload_all_server_settings)

        zone.add_settings_for_resource(settings)

        expect(Vmdb::Settings.for_resource(zone).some_test_setting.setting).to eq(1)
      end
    end

    describe "#reload_all_server_settings" do
      it "queues #reload_settings for the started servers" do
        some_other_zone = FactoryGirl.create(:zone)
        started_server = FactoryGirl.create(:miq_server, :status => "started", :zone => zone)
        FactoryGirl.create(:miq_server, :status => "started", :zone => some_other_zone)
        FactoryGirl.create(:miq_server, :status => "stopped", :zone => zone)

        zone.reload_all_server_settings

        expect(MiqQueue.count).to eq(1)
        message = MiqQueue.first
        expect(message.instance_id).to eq(started_server.id)
        expect(message.method_name).to eq("reload_settings")
      end
    end
  end
end

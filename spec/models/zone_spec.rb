describe Zone do
  include_examples ".seed called multiple times"

  context "with two small envs" do
    before do
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
    before do
      _, _, @zone = EvmSpecHelper.create_guid_miq_server_zone
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
      host
      host_with_cluster

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
      host
      host_with_cluster

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

  it "#settings should always be a hash" do
    expect(described_class.new.settings).to be_kind_of(Hash)
  end

  context "ConfigurationManagementMixin" do
    describe "#remote_cockpit_ws_miq_server" do
      before do
        @csv = <<-CSV.gsub(/^\s+/, "")
          name,description,max_concurrent,external_failover,role_scope
          cockpit_ws,Cockpit,1,false,zone
        CSV
        allow(ServerRole).to receive(:seed_data).and_return(@csv)
        ServerRole.seed
        _, _, @zone = EvmSpecHelper.create_guid_miq_server_zone
      end

      it "none when not enabled" do
        expect(@zone.remote_cockpit_ws_miq_server).to eq(nil)
      end

      it "server when enabled" do
        server = FactoryGirl.create(:miq_server, :has_active_cockpit_ws => true, :zone => @zone)
        server.assign_role('cockpit_ws', 1)
        server.activate_roles('cockpit_ws')
        expect(@zone.remote_cockpit_ws_miq_server).to eq(server)
      end
    end
  end

  context "#ntp_reload_queue" do
    it "queues a ntp reload for all active servers in the zone" do
      expect(MiqEnvironment::Command).to receive(:is_appliance?).and_return(true)
      expect(MiqEnvironment::Command).to receive(:is_container?).and_return(false)
      zone     = FactoryGirl.create(:zone)
      server_1 = FactoryGirl.create(:miq_server, :zone => zone)
      FactoryGirl.create(:miq_server, :zone => zone, :status => "stopped")

      zone.ntp_reload_queue

      expect(MiqQueue.count).to eq(1)
      expect(
        MiqQueue.where(
          :class_name  => "MiqServer",
          :instance_id => server_1.id,
          :method_name => "ntp_reload",
          :server_guid => server_1.guid,
        ).count
      ).to eq(1)
    end
  end

  context "validate multi region" do
    let!(:other_region_id)         { ApplicationRecord.id_in_region(1, ApplicationRecord.my_region_number + 1) }
    let!(:default_in_other_region) { described_class.create(:name => "default", :description => "Default Zone", :id => other_region_id) }
    let!(:default_in_my_region)    { described_class.create(:name => "default", :description => "Default Zone") }

    it ".default_zone returns a zone in the current region" do
      expect(described_class.default_zone).to eq(default_in_my_region)
    end
  end

  it "removes queued items on destroy" do
    zone = FactoryGirl.create(:zone)
    FactoryGirl.create(:miq_queue, :zone => zone.name)
    expect(MiqQueue.where(:zone => zone.name).count).to eq(1)
    zone.destroy!
    expect(MiqQueue.where(:zone => zone.name).count).to eq(0)
  end
end

RSpec.describe Zone do
  include_examples "AggregationMixin", "ext_management_systems"

  context ".seed" do
    before { MiqRegion.seed }
    include_examples ".seed called multiple times", 2
  end

  context "with two small envs" do
    before do
      @zone1 = FactoryBot.create(:small_environment)
      @host1 = @zone1.ext_management_systems.first.hosts.first
      @zone1.reload
      @zone2 = FactoryBot.create(:small_environment)
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
      ems_clouds = FactoryBot.create_list(:ems_openstack, 2, :zone => @zone)
      ems_clouds += FactoryBot.create_list(:ems_amazon, 2, :zone => @zone)
      ems_infra = FactoryBot.create(:ems_vmware, :zone => @zone)

      zone_clouds = @zone.ems_clouds
      expect(zone_clouds).to match_array(ems_clouds)

      expect(zone_clouds).not_to include ems_infra
    end

    it "returns the set of availability_zones" do
      openstack = FactoryBot.create(:ems_openstack, :zone => @zone)
      azs = FactoryBot.create_list(:availability_zone, 3, :ems_id => openstack.id)
      expect(@zone.availability_zones).to match_array(azs)
    end
  end

  describe "#clustered_hosts" do
    let(:zone) { FactoryBot.create(:zone) }
    let(:ems) { FactoryBot.create(:ems_vmware, :zone => zone) }
    let(:cluster) { FactoryBot.create(:ems_cluster, :ext_management_system => ems)}
    let(:host_with_cluster) { FactoryBot.create(:host, :ext_management_system => ems, :ems_cluster => cluster) }
    let(:host) { FactoryBot.create(:host, :ext_management_system => ems) }

    it "returns clustered hosts" do
      host
      host_with_cluster

      expect(zone.clustered_hosts).to eq([host_with_cluster])
    end
  end

  describe "#non_clustered_hosts" do
    let(:zone) { FactoryBot.create(:zone) }
    let(:ems) { FactoryBot.create(:ems_vmware, :zone => zone) }
    let(:cluster) { FactoryBot.create(:ems_cluster, :ext_management_system => ems)}
    let(:host_with_cluster) { FactoryBot.create(:host, :ext_management_system => ems, :ems_cluster => cluster) }
    let(:host) { FactoryBot.create(:host, :ext_management_system => ems) }

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

      expect(zone.active?).to eq(false)
    end
  end

  it "#settings should always be a hash" do
    expect(described_class.new.settings).to be_kind_of(Hash)
  end

  context "ConfigurationManagementMixin" do
    describe "#remote_cockpit_ws_miq_server" do
      before do
        ServerRole.seed
        _, _, @zone = EvmSpecHelper.create_guid_miq_server_zone
      end

      it "none when not enabled" do
        expect(@zone.remote_cockpit_ws_miq_server).to eq(nil)
      end

      it "server when enabled" do
        server = FactoryBot.create(:miq_server, :has_active_cockpit_ws => true, :zone => @zone)
        server.assign_role('cockpit_ws', 1)
        server.activate_roles('cockpit_ws')
        expect(@zone.remote_cockpit_ws_miq_server).to eq(server)
      end
    end
  end

  context "maintenance zone" do
    before { MiqRegion.seed }

    it "is seeded with relation to region" do
      described_class.seed
      expect(Zone.maintenance_zone).to have_attributes(
        :name => a_string_starting_with("__maintenance__")
      )

      expect(MiqRegion.my_region.maintenance_zone).to eq(Zone.maintenance_zone)
    end

    it "is not visible" do
      described_class.seed
      expect(described_class.maintenance_zone.visible).to eq(false)
    end

    it "cannot be destroyed" do
      described_class.seed
      expect { described_class.maintenance_zone.destroy! }.to raise_error(RuntimeError)
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
    MiqRegion.seed
    Zone.seed
    zone = FactoryBot.create(:zone)
    FactoryBot.create(:miq_queue, :zone => zone.name)
    expect(MiqQueue.where(:zone => zone.name).count).to eq(1)
    zone.destroy!
    expect(MiqQueue.where(:zone => zone.name).count).to eq(0)
  end

  it "doesn't create a server for the zone when not podified" do
    zone = FactoryBot.create(:zone)
    expect(zone.miq_servers.count).to eq(0)
  end

  describe "#destroy" do
    before { MiqRegion.seed }

    it "fails for a zone with servers when not podified" do
      zone = FactoryBot.create(:zone)
      zone.miq_servers.create!(:name => "my_server")
      expect { zone.destroy! }.to raise_error(RuntimeError)
    end

    it "fails for the default zone" do
      described_class.seed
      expect { described_class.default_zone.destroy! }.to raise_error(RuntimeError)
    end

    it "fails for a zone with a provider" do
      zone = FactoryBot.create(:zone)
      FactoryBot.create(:ext_management_system, :zone => zone)

      expect { zone.destroy! }.to raise_error(RuntimeError)
    end
  end

  context "when podified" do
    before do
      allow(MiqEnvironment::Command).to receive(:is_podified?).and_return(true)
    end

    describe ".create" do
      it "automatically creates a server" do
        zone = Zone.create!(:name => "my_zone", :description => "some zone")
        expect(zone.miq_servers.count).to eq(1)

        server = zone.miq_servers.first
        expect(server.name).to eq("my_zone")
      end

      it "doesn't create a server for non-visible zones" do
        zone = Zone.create!(:name => "my_zone", :description => "some zone", :visible => false)
        expect(zone.miq_servers.count).to eq(0)
      end

      it "doesn't create a server for the default zone" do
        zone = Zone.create!(:name => "default", :description => "Default Zone")
        expect(zone.miq_servers.count).to eq(0)
      end
    end

    it ".destroy deletes the server in the zone" do
      MiqRegion.seed
      zone = Zone.create!(:name => "my_zone", :description => "some zone")
      server = zone.miq_servers.first
      zone.destroy!

      expect(MiqServer.find_by(:id => server.id)).to be_nil
    end
  end

  describe "#message_for_invalid_delete" do
    it "returns an error for the default zone" do
      described_class.seed
      message = described_class.default_zone.message_for_invalid_delete
      expect(message).to eq("cannot delete default zone")
    end

    it "returns an error for the maintenance zone" do
      described_class.seed
      message = described_class.maintenance_zone.message_for_invalid_delete
      expect(message).to eq("cannot delete maintenance zone")
    end

    it "returns an error when the zone has providers" do
      zone = FactoryBot.create(:zone)
      FactoryBot.create(:ext_management_system, :zone => zone)
      message = zone.message_for_invalid_delete
      expect(message).to eq("zone name '#{zone.name}' is used by a provider")
    end

    it "returns an error when the zone has servers and not running in pods" do
      zone = FactoryBot.create(:miq_server).zone
      message = zone.message_for_invalid_delete
      expect(message).to eq("zone name '#{zone.name}' is used by a server")
    end

    it "does not return an error when the zone has a server and running in pods" do
      allow(MiqEnvironment::Command).to receive(:is_podified?).and_return(true)
      zone = FactoryBot.create(:miq_server).zone
      message = zone.message_for_invalid_delete
      expect(message).to be_nil
    end
  end

  context "#valid?" do
    it "doesn't query for an unchanged record" do
      zone = FactoryBot.create(:zone)
      expect { zone.valid? }.not_to make_database_queries
    end
  end
end

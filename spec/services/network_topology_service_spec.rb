describe NetworkTopologyService do
  let(:network_topology_service) { described_class.new(nil) }

  describe "#build_kinds" do
    it "creates the expected number of entity types" do
      expect(network_topology_service.build_kinds.keys).to match_array([
                                                                         :CloudNetwork, :CloudSubnet, :CloudTenant, :FloatingIp, :LoadBalancer, :NetworkManager, :NetworkPort, :NetworkRouter,
                                                                         :SecurityGroup, :Tag, :Vm, :AvailabilityZone
                                                                       ])
    end
  end

  describe "#build_link" do
    it "creates link between source to target" do
      expect(network_topology_service.build_link(
               "95e49048-3e00-11e5-a0d2-18037327aaeb",
               "96c35f65-3e00-11e5-a0d2-18037327aaeb"
      )).to eq(:source => "95e49048-3e00-11e5-a0d2-18037327aaeb",
               :target => "96c35f65-3e00-11e5-a0d2-18037327aaeb")
    end
  end

  describe "#build_topology" do
    subject { network_topology_service.build_topology }

    let(:ems_cloud) { FactoryGirl.create(:ems_openstack) }
    let(:ems) { ems_cloud.network_manager }

    before :each do
      @cloud_tenant = FactoryGirl.create(:cloud_tenant_openstack)
      @availability_zone = FactoryGirl.create(:availability_zone_openstack,
                                              :name                  => "AZ name",
                                              :ext_management_system => ems_cloud)
      @vm = FactoryGirl.create(:vm_openstack,
                               :cloud_tenant          => @cloud_tenant,
                               :ext_management_system => ems_cloud,
                               :availability_zone     => @availability_zone)
      @cloud_network = FactoryGirl.create(:cloud_network_openstack)
      @public_network = FactoryGirl.create(:cloud_network_openstack)
      @cloud_subnet = FactoryGirl.create(:cloud_subnet_openstack, :cloud_network         => @cloud_network,
                                                                  :ext_management_system => ems)
      @network_router = FactoryGirl.create(:network_router_openstack, :cloud_subnets => [@cloud_subnet],
                                                                      :cloud_network => @public_network)
      @floating_ip = FactoryGirl.create(:floating_ip_openstack, :vm => @vm, :cloud_network => @public_network)
      @security_group = FactoryGirl.create(:security_group_openstack)
      @network_port = FactoryGirl.create(:network_port_openstack, :device          => @vm,
                                                                  :security_groups => [@security_group],
                                                                  :floating_ip     => @floating_ip)
      @cloud_subnet_network_port = FactoryGirl.create(:cloud_subnet_network_port, :cloud_subnet => @cloud_subnet,
                                                                                  :network_port => @network_port)
    end

    it "topology contains only the expected keys" do
      expect(subject.keys).to match_array([:items, :kinds, :relations, :icons])
    end

    it "provider has unknown status when no authentication exists" do
      ems = FactoryGirl.create(:ems_openstack).network_manager

      allow(network_topology_service).to receive(:retrieve_providers).with(
        anything, ManageIQ::Providers::NetworkManager
      ).and_return([ems])
      network_topology_service.instance_variable_set(:@providers,
                                                     ManageIQ::Providers::NetworkManager.where(:id => ems.id))

      expect(subject[:items]).to eq(
        "NetworkManager" + ems.compressed_id.to_s => {:name         => ems.name,
                                                      :status       => "Unknown",
                                                      :kind         => "NetworkManager",
                                                      :display_kind => "Openstack",
                                                      :miq_id       => ems.id}
      )
    end

    it "topology contains the expected structure and content" do
      allow(network_topology_service).to receive(:retrieve_providers).and_return([ems])
      network_topology_service.instance_variable_set(:@entity, ems)

      expect(subject[:items]).to(
        eq(
          "NetworkManager" + ems.compressed_id.to_s                  => {
            :name         => ems.name,
            :kind         => "NetworkManager",
            :miq_id       => ems.id,
            :status       => "Unknown",
            :display_kind => "Openstack"
          },
          "AvailabilityZone" + @availability_zone.compressed_id.to_s => {
            :name         => "AZ name",
            :kind         => "AvailabilityZone",
            :miq_id       => @availability_zone.id,
            :status       => "Unknown",
            :display_kind => "AvailabilityZone"
          },
          "CloudTenant" + @cloud_tenant.compressed_id.to_s           => {
            :name         => @cloud_tenant.name,
            :kind         => "CloudTenant",
            :miq_id       => @cloud_tenant.id,
            :status       => "Unknown",
            :display_kind => "CloudTenant"
          },
          "CloudNetwork" + @cloud_network.compressed_id.to_s         => {
            :name         => @cloud_network.name,
            :kind         => "CloudNetwork",
            :miq_id       => @cloud_network.id,
            :status       => "Unknown",
            :display_kind => "CloudNetwork"
          },
          "CloudNetwork" + @public_network.compressed_id.to_s        => {
            :name         => @public_network.name,
            :kind         => "CloudNetwork",
            :miq_id       => @public_network.id,
            :status       => "Unknown",
            :display_kind => "CloudNetwork"
          },
          "CloudSubnet" + @cloud_subnet.compressed_id.to_s           => {
            :name         => @cloud_subnet.name,
            :kind         => "CloudSubnet",
            :miq_id       => @cloud_subnet.id,
            :status       => "Unknown",
            :display_kind => "CloudSubnet"
          },
          "FloatingIp" + @floating_ip.compressed_id.to_s             => {
            :name         => @floating_ip.name,
            :kind         => "FloatingIp",
            :miq_id       => @floating_ip.id,
            :status       => "Unknown",
            :display_kind => "FloatingIp"
          },
          "NetworkRouter" + @network_router.compressed_id.to_s       => {
            :name         => @network_router.name,
            :kind         => "NetworkRouter",
            :miq_id       => @network_router.id,
            :status       => "Unknown",
            :display_kind => "NetworkRouter"
          },

          "SecurityGroup" + @security_group.compressed_id.to_s       => {
            :name         => @security_group.name,
            :kind         => "SecurityGroup",
            :miq_id       => @security_group.id,
            :status       => "Unknown",
            :display_kind => "SecurityGroup"
          },
          "Vm" + @vm.compressed_id.to_s                              => {
            :name         => @vm.name,
            :kind         => "Vm",
            :miq_id       => @vm.id,
            :status       => "On",
            :display_kind => "VM",
            :provider     => ems_cloud.name
          },
        )
      )

      expect(subject[:relations].size).to eq(11)
      expect(subject[:relations]).to include(
        {:source => "NetworkManager" + ems.compressed_id.to_s, :target => "CloudSubnet" + @cloud_subnet.compressed_id.to_s},
        {:source => "NetworkManager" + ems.compressed_id.to_s, :target => "CloudSubnet" + @cloud_subnet.compressed_id.to_s},
        {:source => "AvailabilityZone" + @availability_zone.compressed_id.to_s, :target => "Vm" + @vm.compressed_id.to_s},
        {:source => "CloudSubnet" + @cloud_subnet.compressed_id.to_s, :target => "CloudNetwork" + @cloud_network.compressed_id.to_s},
        {:source => "CloudSubnet" + @cloud_subnet.compressed_id.to_s, :target => "Vm" + @vm.compressed_id.to_s},
        {:source => "Vm" + @vm.compressed_id.to_s, :target => "FloatingIp" + @floating_ip.compressed_id.to_s},
        {:source => "Vm" + @vm.compressed_id.to_s, :target => "CloudTenant" + @cloud_tenant.compressed_id.to_s},
        {:source => "Vm" + @vm.compressed_id.to_s, :target => "SecurityGroup" + @security_group.compressed_id.to_s},
        {:source => "CloudSubnet" + @cloud_subnet.compressed_id.to_s, :target => "NetworkRouter" + @network_router.compressed_id.to_s},
        {:source => "NetworkRouter" + @network_router.compressed_id.to_s, :target => "CloudNetwork" + @public_network.compressed_id.to_s},
        {:source => "CloudNetwork" + @public_network.compressed_id.to_s, :target => "FloatingIp" + @floating_ip.compressed_id.to_s},
      )
    end

    it "topology contains the expected structure when vm is off" do
      # vm and host test cross provider correlation to infra provider
      @vm.update_attributes(:raw_power_state => "SHUTOFF")
      allow(network_topology_service).to receive(:retrieve_providers).and_return([ems])
      network_topology_service.instance_variable_set(:@entity, ems)

      expect(subject[:items]).to(
        eq(
          "NetworkManager" + ems.compressed_id.to_s                  => {
            :name         => ems.name,
            :kind         => "NetworkManager",
            :miq_id       => ems.id,
            :status       => "Unknown",
            :display_kind => "Openstack"
          },
          "AvailabilityZone" + @availability_zone.compressed_id.to_s => {
            :name         => "AZ name",
            :kind         => "AvailabilityZone",
            :miq_id       => @availability_zone.id,
            :status       => "Unknown",
            :display_kind => "AvailabilityZone"
          },
          "CloudTenant" + @cloud_tenant.compressed_id.to_s           => {
            :name         => @cloud_tenant.name,
            :kind         => "CloudTenant",
            :miq_id       => @cloud_tenant.id,
            :status       => "Unknown",
            :display_kind => "CloudTenant"
          },
          "CloudNetwork" + @cloud_network.compressed_id.to_s         => {
            :name         => @cloud_network.name,
            :kind         => "CloudNetwork",
            :miq_id       => @cloud_network.id,
            :status       => "Unknown",
            :display_kind => "CloudNetwork"
          },
          "CloudNetwork" + @public_network.compressed_id.to_s        => {
            :name         => @public_network.name,
            :kind         => "CloudNetwork",
            :miq_id       => @public_network.id,
            :status       => "Unknown",
            :display_kind => "CloudNetwork"
          },
          "CloudSubnet" + @cloud_subnet.compressed_id.to_s           => {
            :name         => @cloud_subnet.name,
            :kind         => "CloudSubnet",
            :miq_id       => @cloud_subnet.id,
            :status       => "Unknown",
            :display_kind => "CloudSubnet"
          },
          "FloatingIp" + @floating_ip.compressed_id.to_s             => {
            :name         => @floating_ip.name,
            :kind         => "FloatingIp",
            :miq_id       => @floating_ip.id,
            :status       => "Unknown",
            :display_kind => "FloatingIp"
          },
          "NetworkRouter" + @network_router.compressed_id.to_s       => {
            :name         => @network_router.name,
            :kind         => "NetworkRouter",
            :miq_id       => @network_router.id,
            :status       => "Unknown",
            :display_kind => "NetworkRouter"
          },
          "SecurityGroup" + @security_group.compressed_id.to_s       => {
            :name         => @security_group.name,
            :kind         => "SecurityGroup",
            :miq_id       => @security_group.id,
            :status       => "Unknown",
            :display_kind => "SecurityGroup"
          },
          "Vm" + @vm.compressed_id.to_s                              => {
            :name         => @vm.name,
            :kind         => "Vm",
            :miq_id       => @vm.id,
            :status       => "Off",
            :display_kind => "VM",
            :provider     => ems_cloud.name
          },
        )
      )

      expect(subject[:relations].size).to eq(11)
      expect(subject[:relations]).to include(
        {:source => "NetworkManager" + ems.compressed_id.to_s, :target => "AvailabilityZone" + @availability_zone.compressed_id.to_s},
        {:source => "NetworkManager" + ems.compressed_id.to_s, :target => "CloudSubnet" + @cloud_subnet.compressed_id.to_s},
        {:source => "AvailabilityZone" + @availability_zone.compressed_id.to_s, :target => "Vm" + @vm.compressed_id.to_s},
        {:source => "CloudSubnet" + @cloud_subnet.compressed_id.to_s, :target => "CloudNetwork" + @cloud_network.compressed_id.to_s},
        {:source => "CloudSubnet" + @cloud_subnet.compressed_id.to_s, :target => "Vm" + @vm.compressed_id.to_s},
        {:source => "Vm" + @vm.compressed_id.to_s, :target => "FloatingIp" + @floating_ip.compressed_id.to_s},
        {:source => "Vm" + @vm.compressed_id.to_s, :target => "CloudTenant" + @cloud_tenant.compressed_id.to_s},
        {:source => "Vm" + @vm.compressed_id.to_s, :target => "SecurityGroup" + @security_group.compressed_id.to_s},
        {:source => "CloudSubnet" + @cloud_subnet.compressed_id.to_s, :target => "NetworkRouter" + @network_router.compressed_id.to_s},
        {:source => "NetworkRouter" + @network_router.compressed_id.to_s, :target => "CloudNetwork" + @public_network.compressed_id.to_s},
        {:source => "CloudNetwork" + @public_network.compressed_id.to_s, :target => "FloatingIp" + @floating_ip.compressed_id.to_s},
      )
    end
  end
end

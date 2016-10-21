describe CloudTopologyService do
  let(:cloud_topology_service) { described_class.new(nil) }

  describe "#build_kinds" do
    it "creates the expected number of entity types" do
      expect(cloud_topology_service.build_kinds.keys).to match_array(
        [:AvailabilityZone, :CloudManager, :CloudTenant, :Tag, :Vm])
    end
  end

  describe "#build_link" do
    it "creates link between source to target" do
      expect(cloud_topology_service.build_link(
               "95e49048-3e00-11e5-a0d2-18037327aaeb",
               "96c35f65-3e00-11e5-a0d2-18037327aaeb")).to eq(:source => "95e49048-3e00-11e5-a0d2-18037327aaeb",
                                                              :target => "96c35f65-3e00-11e5-a0d2-18037327aaeb")
    end
  end

  describe "#build_topology" do
    subject { cloud_topology_service.build_topology }

    let(:ems) { FactoryGirl.create(:ems_openstack) }

    before :each do
      @availability_zone = FactoryGirl.create(:availability_zone_openstack, :ext_management_system => ems)
      @cloud_tenant = FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems)
      @vm = FactoryGirl.create(:vm_openstack, :cloud_tenant => @cloud_tenant, :ext_management_system => ems)
    end

    it "topology contains only the expected keys" do
      expect(subject.keys).to match_array([:items, :kinds, :relations, :icons])
    end

    it "provider has unknown status when no authentication exists" do
      ems = FactoryGirl.create(:ems_openstack)

      allow(cloud_topology_service)
        .to receive(:retrieve_providers)
        .with(anything, ManageIQ::Providers::CloudManager)
        .and_return([ems])

      cloud_topology_service
        .instance_variable_set(:@providers, ManageIQ::Providers::CloudManager.where(:id => ems.id))

      expect(subject[:items]).to eq(
        "CloudManager" + ems.compressed_id.to_s =>   {:name         => ems.name,
                                                      :status       => "Unknown",
                                                      :kind         => "CloudManager",
                                                      :display_kind => "Openstack",
                                                      :miq_id       => ems.id})
    end

    it "topology contains the expected structure and content" do
      allow(cloud_topology_service).to receive(:retrieve_providers).and_return([ems])
      cloud_topology_service.instance_variable_set(:@entity, ems)

      expect(subject[:items]).to eq(
        "CloudManager" + ems.compressed_id.to_s                         => {:name         => ems.name,
                                                                            :kind         => "CloudManager",
                                                                            :miq_id       => ems.id,
                                                                            :status       => "Unknown",
                                                                            :display_kind => "Openstack"},
        "AvailabilityZone" + @availability_zone.compressed_id.to_s      => {:name         => @availability_zone.name,
                                                                            :kind         => "AvailabilityZone",
                                                                            :miq_id       => @availability_zone.id,
                                                                            :status       => "OK",
                                                                            :display_kind => "AvailabilityZone",
                                                                            :provider     => ems.name},
        "CloudTenant" + @cloud_tenant.compressed_id.to_s                => {:name         => @cloud_tenant.name,
                                                                            :kind         => "CloudTenant",
                                                                            :miq_id       => @cloud_tenant.id,
                                                                            :status       => "Unknown",
                                                                            :display_kind => "CloudTenant",
                                                                            :provider     => ems.name},
        "Vm" + @vm.compressed_id.to_s                                   => {:name         => @vm.name,
                                                                            :kind         => "Vm",
                                                                            :miq_id       => @vm.id,
                                                                            :status       => "On",
                                                                            :display_kind => "VM",
                                                                            :provider     => ems.name},
      )

      expect(subject[:relations].size).to eq(3)
      expect(subject[:relations]).to include(
        {:source => "CloudManager" + ems.compressed_id.to_s, :target => "AvailabilityZone" + @availability_zone.compressed_id.to_s},
        {:source => "CloudManager" + ems.compressed_id.to_s, :target => "CloudTenant" + @cloud_tenant.compressed_id.to_s},
        {:source => "CloudTenant" + @cloud_tenant.compressed_id.to_s, :target => "Vm" + @vm.compressed_id.to_s},
      )
    end

    it "topology contains the expected structure when vm is off" do
      # vm and host test cross provider correlation to infra provider
      @vm.update_attributes(:raw_power_state => "SHUTOFF")
      allow(cloud_topology_service).to receive(:retrieve_providers).and_return([ems])
      cloud_topology_service.instance_variable_set(:@entity, ems)

      expect(subject[:items]).to eq(
        "CloudManager" + ems.compressed_id.to_s                         => {:name         => ems.name,
                                                                            :kind         => "CloudManager",
                                                                            :miq_id       => ems.id,
                                                                            :status       => "Unknown",
                                                                            :display_kind => "Openstack"},
        "AvailabilityZone" + @availability_zone.compressed_id.to_s      => {:name         => @availability_zone.name,
                                                                            :kind         => "AvailabilityZone",
                                                                            :miq_id       => @availability_zone.id,
                                                                            :status       => "OK",
                                                                            :display_kind => "AvailabilityZone",
                                                                            :provider     => ems.name},
        "CloudTenant" + @cloud_tenant.compressed_id.to_s                => {:name         => @cloud_tenant.name,
                                                                            :kind         => "CloudTenant",
                                                                            :miq_id       => @cloud_tenant.id,
                                                                            :status       => "Unknown",
                                                                            :display_kind => "CloudTenant",
                                                                            :provider     => ems.name},
        "Vm" + @vm.compressed_id.to_s                                   => {:name         => @vm.name,
                                                                            :kind         => "Vm",
                                                                            :miq_id       => @vm.id,
                                                                            :status       => "Off",
                                                                            :display_kind => "VM",
                                                                            :provider     => ems.name},
      )

      expect(subject[:relations].size).to eq(3)
      expect(subject[:relations]).to include(
        {:source => "CloudManager" + ems.compressed_id.to_s, :target => "AvailabilityZone" + @availability_zone.compressed_id.to_s},
        {:source => "CloudManager" + ems.compressed_id.to_s, :target => "CloudTenant" + @cloud_tenant.compressed_id.to_s},
        {:source => "CloudTenant" + @cloud_tenant.compressed_id.to_s, :target => "Vm" + @vm.compressed_id.to_s},
      )
    end
  end
end

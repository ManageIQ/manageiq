module MiqAeServiceHostAggregateOpenstackSpec
  describe MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_CloudManager_HostAggregate do
    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#cloud_tenant" do
      expect(described_class.instance_methods).to include(:availability_zone)
    end

    it "#used" do
      expect(described_class.instance_methods).to include(:availability_zone_obj)
    end

    it "#update_aggregate" do
      expect(described_class.instance_methods).to include(:update_aggregate)
    end

    it "#delete_aggregate" do
      expect(described_class.instance_methods).to include(:delete_aggregate)
    end

    it "#add_host" do
      expect(described_class.instance_methods).to include(:add_host)
    end

    it "#remove_host" do
      expect(described_class.instance_methods).to include(:remove_host)
    end
  end
end

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
  end
end

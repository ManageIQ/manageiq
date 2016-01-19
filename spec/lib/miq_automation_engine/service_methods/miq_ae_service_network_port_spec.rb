module MiqAeServiceCloudNetworkSpec
  describe MiqAeMethodService::MiqAeServiceNetworkPort do
    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#cloud_tenant" do
      expect(described_class.instance_methods).to include(:cloud_tenant)
    end

    it "#cloud_subnet" do
      expect(described_class.instance_methods).to include(:cloud_subnet)
    end

    it "#device" do
      expect(described_class.instance_methods).to include(:device)
    end
  end
end

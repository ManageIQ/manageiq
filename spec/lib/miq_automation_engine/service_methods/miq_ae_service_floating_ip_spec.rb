module MiqAeServiceFloatingIpSpec
  describe MiqAeMethodService::MiqAeServiceFloatingIp do
    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#vm" do
      expect(described_class.instance_methods).to include(:vm)
    end

    it "#cloud_tenant" do
      expect(described_class.instance_methods).to include(:cloud_tenant)
    end
  end
end

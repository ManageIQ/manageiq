module MiqAeServiceCloudNetworkSpec
  describe MiqAeMethodService::MiqAeServiceCloudNetwork do
    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#cloud_tenant" do
      expect(described_class.instance_methods).to include(:cloud_tenant)
    end

    it "#cloud_subnets" do
      expect(described_class.instance_methods).to include(:cloud_subnets)
    end

    it "#security_groups" do
      expect(described_class.instance_methods).to include(:security_groups)
    end

    it "#vms" do
      expect(described_class.instance_methods).to include(:vms)
    end

    it "#floating_ips" do
      expect(described_class.instance_methods).to include(:floating_ips)
    end

    it "#network_ports" do
      expect(described_class.instance_methods).to include(:network_ports)
    end

    it "#network_routers" do
      expect(described_class.instance_methods).to include(:network_routers)
    end
  end
end

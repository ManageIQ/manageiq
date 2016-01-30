module MiqAeServiceSecurityGroupSpec
  describe MiqAeMethodService::MiqAeServiceSecurityGroup do
    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#cloud_network" do
      expect(described_class.instance_methods).to include(:cloud_network)
    end

    it "#cloud_tenant" do
      expect(described_class.instance_methods).to include(:cloud_tenant)
    end

    it "#firewall_rules" do
      expect(described_class.instance_methods).to include(:firewall_rules)
    end

    it "#vms" do
      expect(described_class.instance_methods).to include(:vms)
    end
  end
end

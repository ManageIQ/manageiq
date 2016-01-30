module MiqAeServiceCloudNetworkSpec
  describe MiqAeMethodService::MiqAeServiceNetworkRouter do
    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#cloud_tenant" do
      expect(described_class.instance_methods).to include(:cloud_tenant)
    end

    it "#public_network" do
      expect(described_class.instance_methods).to include(:public_network)
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

    it "#vms" do
      expect(described_class.instance_methods).to include(:vms)
    end

    it "#private_networks" do
      expect(described_class.instance_methods).to include(:private_networks)
    end
  end
end

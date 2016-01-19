module MiqAeServiceCloudSubnetSpec
  describe MiqAeMethodService::MiqAeServiceCloudSubnet do
    it "#cloud_network" do
      expect(described_class.instance_methods).to include(:cloud_network)
    end

    it "#availability_zone" do
      expect(described_class.instance_methods).to include(:availability_zone)
    end

    it "#vms" do
      expect(described_class.instance_methods).to include(:vms)
    end
  end
end

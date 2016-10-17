module MiqAeServiceEmsCloudSpec
  describe MiqAeMethodService::MiqAeServiceManageIQ_Providers_CloudManager do
    it "#availability_zones" do
      expect(described_class.instance_methods).to include(:availability_zones)
    end

    it "#cloud_networks" do
      expect(described_class.instance_methods).to include(:cloud_networks)
    end

    it "#cloud_tenants" do
      expect(described_class.instance_methods).to include(:cloud_tenants)
    end

    it "#flavors" do
      expect(described_class.instance_methods).to include(:flavors)
    end

    it "#floating_ips" do
      expect(described_class.instance_methods).to include(:floating_ips)
    end

    it "#key_pairs" do
      expect(described_class.instance_methods).to include(:key_pairs)
    end

    it "#security_groups" do
      expect(described_class.instance_methods).to include(:security_groups)
    end

    it "#cloud_resource_quotas" do
      expect(described_class.instance_methods).to include(:cloud_resource_quotas)
    end

    it "#cloud_networks_public" do
      expect(described_class.instance_methods).to include(:public_networks)
    end

    it "#cloud_networks_private" do
      expect(described_class.instance_methods).to include(:private_networks)
    end

    it "#host_aggregates" do
      expect(described_class.instance_methods).to include(:host_aggregates)
    end
  end
end

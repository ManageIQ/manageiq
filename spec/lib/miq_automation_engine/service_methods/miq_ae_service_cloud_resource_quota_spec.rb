module MiqAeServiceCloudResourceQuotaSpec
  describe MiqAeMethodService::MiqAeServiceCloudResourceQuota do
    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#cloud_tenant" do
      expect(described_class.instance_methods).to include(:cloud_tenant)
    end

    it "#used" do
      expect(described_class.instance_methods).to include(:used)
    end
  end
end

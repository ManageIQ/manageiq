require "spec_helper"

module MiqAeServiceCloudTenantSpec
  describe MiqAeMethodService::MiqAeServiceCloudTenant do
    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#security_groups" do
      expect(described_class.instance_methods).to include(:security_groups)
    end

    it "#cloud_networks" do
      expect(described_class.instance_methods).to include(:cloud_networks)
    end

    it "#vms" do
      expect(described_class.instance_methods).to include(:vms)
    end

    it "#vms_and_templates" do
      expect(described_class.instance_methods).to include(:vms_and_templates)
    end

    it "#miq_templates" do
      expect(described_class.instance_methods).to include(:miq_templates)
    end

    it "#floating_ips" do
      expect(described_class.instance_methods).to include(:floating_ips)
    end

    it "#cloud_resource_quotas" do
      expect(described_class.instance_methods).to include(:cloud_resource_quotas)
    end
  end
end

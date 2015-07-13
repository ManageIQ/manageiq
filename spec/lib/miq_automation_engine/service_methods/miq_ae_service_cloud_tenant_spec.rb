require "spec_helper"

module MiqAeServiceCloudTenantSpec
  describe MiqAeMethodService::MiqAeServiceCloudTenant do
    it "#ext_management_system" do
      described_class.instance_methods.should include(:ext_management_system)
    end

    it "#security_groups" do
      described_class.instance_methods.should include(:security_groups)
    end

    it "#cloud_networks" do
      described_class.instance_methods.should include(:cloud_networks)
    end

    it "#vms" do
      described_class.instance_methods.should include(:vms)
    end

    it "#vms_and_templates" do
      described_class.instance_methods.should include(:vms_and_templates)
    end

    it "#miq_templates" do
      described_class.instance_methods.should include(:miq_templates)
    end

    it "#floating_ips" do
      described_class.instance_methods.should include(:floating_ips)
    end

    it "#cloud_resource_quotas" do
      described_class.instance_methods.should include(:cloud_resource_quotas)
    end
  end
end

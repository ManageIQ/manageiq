require "spec_helper"

module MiqAeServiceCloudResourceQuotaOpenstackSpec
  describe MiqAeMethodService::MiqAeServiceCloudResourceQuotaOpenstack do
    it "#ext_management_system" do
      described_class.instance_methods.should include(:ext_management_system)
    end

    it "#cloud_tenant" do
      described_class.instance_methods.should include(:cloud_tenant)
    end

    it "#used" do
      described_class.instance_methods.should include(:used)
    end
  end
end

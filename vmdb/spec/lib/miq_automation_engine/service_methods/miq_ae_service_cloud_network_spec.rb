require "spec_helper"

module MiqAeServiceCloudNetworkSpec
  describe MiqAeMethodService::MiqAeServiceCloudNetwork do
    it "#ext_management_system" do
      described_class.instance_methods.should include(:ext_management_system)
    end

    it "#cloud_tenant" do
      described_class.instance_methods.should include(:cloud_tenant)
    end

    it "#cloud_subnets" do
      described_class.instance_methods.should include(:cloud_subnets)
    end

    it "#security_groups" do
      described_class.instance_methods.should include(:security_groups)
    end

    it "#vms" do
      described_class.instance_methods.should include(:vms)
    end
  end
end

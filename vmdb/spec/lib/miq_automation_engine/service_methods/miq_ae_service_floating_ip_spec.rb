require "spec_helper"

module MiqAeServiceFloatingIpSpec
  describe MiqAeMethodService::MiqAeServiceFloatingIp do
    it "#ext_management_system" do
      described_class.instance_methods.should include(:ext_management_system)
    end

    it "#vm" do
      described_class.instance_methods.should include(:vm)
    end

    it "#cloud_tenant" do
      described_class.instance_methods.should include(:cloud_tenant)
    end
  end
end

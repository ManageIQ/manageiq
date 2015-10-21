require "spec_helper"

module MiqAeServiceCloudNetworkSpec
  describe MiqAeMethodService::MiqAeServiceNetworkPort do
    it "#ext_management_system" do
      described_class.instance_methods.should include(:ext_management_system)
    end

    it "#cloud_tenant" do
      described_class.instance_methods.should include(:cloud_tenant)
    end

    it "#cloud_subnet" do
      described_class.instance_methods.should include(:cloud_subnet)
    end

    it "#cloud_network" do
      described_class.instance_methods.should include(:cloud_network)
    end

    it "#device" do
      described_class.instance_methods.should include(:device)
    end
  end
end

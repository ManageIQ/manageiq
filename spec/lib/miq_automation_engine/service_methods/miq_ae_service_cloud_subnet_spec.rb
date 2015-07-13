require "spec_helper"

module MiqAeServiceCloudSubnetSpec
  describe MiqAeMethodService::MiqAeServiceCloudSubnet do
    it "#cloud_network" do
      described_class.instance_methods.should include(:cloud_network)
    end

    it "#availability_zone" do
      described_class.instance_methods.should include(:availability_zone)
    end

    it "#vms" do
      described_class.instance_methods.should include(:vms)
    end
  end
end

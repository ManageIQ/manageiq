require "spec_helper"

module MiqAeServiceCloudNetworkSpec
  describe MiqAeMethodService::MiqAeServiceNetworkRouter do
    it "#ext_management_system" do
      described_class.instance_methods.should include(:ext_management_system)
    end

    it "#cloud_tenant" do
      described_class.instance_methods.should include(:cloud_tenant)
    end

    it "#public_network" do
      described_class.instance_methods.should include(:public_network)
    end

    it "#vms" do
      described_class.instance_methods.should include(:vms)
    end

    it "#floating_ips" do
      described_class.instance_methods.should include(:floating_ips)
    end

    it "#network_ports" do
      described_class.instance_methods.should include(:network_ports)
    end

    it "#vms" do
      described_class.instance_methods.should include(:vms)
    end

    it "#private_networks" do
      described_class.instance_methods.should include(:private_networks)
    end
  end
end

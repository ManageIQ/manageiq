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

    it "#floating_ips" do
      described_class.instance_methods.should include(:floating_ips)
    end

    it "#network_ports" do
      described_class.instance_methods.should include(:network_ports)
    end

    it "#network_routers" do
      described_class.instance_methods.should include(:network_routers)
    end

    it "#public_networks" do
      described_class.instance_methods.should include(:public_networks)
    end

    it "#private_networks" do
      described_class.instance_methods.should include(:private_networks)
    end
  end
end

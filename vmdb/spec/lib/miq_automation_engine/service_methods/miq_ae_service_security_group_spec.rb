require "spec_helper"

module MiqAeServiceSecurityGroupSpec
  describe MiqAeMethodService::MiqAeServiceSecurityGroup do
    it "#ext_management_system" do
      described_class.instance_methods.should include(:ext_management_system)
    end

    it "#cloud_network" do
      described_class.instance_methods.should include(:cloud_network)
    end

    it "#cloud_tenant" do
      described_class.instance_methods.should include(:cloud_tenant)
    end

    it "#firewall_rules" do
      described_class.instance_methods.should include(:firewall_rules)
    end

    it "#vms" do
      described_class.instance_methods.should include(:vms)
    end
  end
end

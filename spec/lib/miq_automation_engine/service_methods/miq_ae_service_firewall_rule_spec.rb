require "spec_helper"

module MiqAeServiceFirewallRuleSpec
  describe MiqAeMethodService::MiqAeServiceFirewallRule do
    it "#resource" do
      described_class.instance_methods.should include(:resource)
    end

    it "#source_security_group" do
      described_class.instance_methods.should include(:source_security_group)
    end
  end
end

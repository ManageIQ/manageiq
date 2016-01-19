module MiqAeServiceFirewallRuleSpec
  describe MiqAeMethodService::MiqAeServiceFirewallRule do
    it "#resource" do
      expect(described_class.instance_methods).to include(:resource)
    end

    it "#source_security_group" do
      expect(described_class.instance_methods).to include(:source_security_group)
    end
  end
end

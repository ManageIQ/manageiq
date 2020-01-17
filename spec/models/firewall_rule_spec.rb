RSpec.describe FirewallRule do
  let(:firewall_rule) { FactoryBot.create(:firewall_rule) }

  context "#operating_system" do
    it "with an OperatingSystem" do
      os = FactoryBot.create(:operating_system)
      firewall_rule.update(:resource_type => "OperatingSystem", :resource_id => os.id)

      expect(firewall_rule.operating_system).to eq(os)
    end

    it "with a non-OperatingSystem" do
      sg = FactoryBot.create(:security_group)
      firewall_rule.update(:resource_type => "SecurityGroup", :resource_id => sg.id)

      expect(firewall_rule.operating_system).to be_nil
    end
  end

  context "#operating_system=" do
    it "with an OperatingSystem" do
      os = FactoryBot.create(:operating_system)

      firewall_rule.operating_system = os

      expect(firewall_rule).to have_attributes(
        :resource_type => "OperatingSystem",
        :resource_id   => os.id
      )
    end

    it "with a non-OperatingSystem" do
      sg = FactoryBot.create(:security_group)

      expect { firewall_rule.operating_system = sg }.to raise_error(ArgumentError)
    end
  end
end

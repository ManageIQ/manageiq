require "spec_helper"

describe FirewallRule do
  let(:firewall_rule) { FactoryGirl.create(:firewall_rule) }

  context "#operating_system" do
    it "with an OperatingSystem" do
      os = FactoryGirl.create(:operating_system)
      firewall_rule.update_attributes(:resource_type => "OperatingSystem", :resource_id => os.id)

      firewall_rule.operating_system.should == os
    end

    it "with a non-OperatingSystem" do
      sg = FactoryGirl.create(:security_group)
      firewall_rule.update_attributes(:resource_type => "SecurityGroup", :resource_id => sg.id)

      firewall_rule.operating_system.should be_nil
    end
  end

  context "#operating_system=" do
    it "with an OperatingSystem" do
      os = FactoryGirl.create(:operating_system)

      firewall_rule.operating_system = os

      firewall_rule.should have_attributes(
        :resource_type => "OperatingSystem",
        :resource_id   => os.id
      )
    end

    it "with a non-OperatingSystem" do
      sg = FactoryGirl.create(:security_group)

      lambda { firewall_rule.operating_system = sg }.should raise_error(ArgumentError)
    end
  end
end

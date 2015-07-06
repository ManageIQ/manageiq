require "spec_helper"
require Rails.root.join("db/migrate/20130725224004_change_firewall_rules_to_polymorphic.rb")

describe ChangeFirewallRulesToPolymorphic do
  migration_context :up do
    let(:firewall_rule_stub) { migration_stub(:FirewallRule) }

    it "migrates operating_system_id to polymorphic columns" do
      f = firewall_rule_stub.create!(:operating_system_id => 42)

      migrate

      f.reload.should have_attributes(
        :resource_type => "OperatingSystem",
        :resource_id   => 42
      )
    end
  end

  migration_context :down do
    let(:firewall_rule_stub) { migration_stub(:FirewallRule) }

    it "migrates polymorphic columns to operating_system_id" do
      f_os    = firewall_rule_stub.create!(:resource_type => "OperatingSystem", :resource_id => 42)
      f_other = firewall_rule_stub.create!(:resource_type => "SecurityGroup",   :resource_id => 43)

      migrate

      f_os.reload.operating_system_id.should == 42
      lambda { f_other.reload }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end
end

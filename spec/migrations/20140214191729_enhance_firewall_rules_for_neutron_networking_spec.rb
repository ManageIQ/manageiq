require "spec_helper"
require Rails.root.join("db/migrate/20140214191729_enhance_firewall_rules_for_neutron_networking.rb")

describe EnhanceFirewallRulesForNeutronNetworking do
  let(:firewall_rule_stub) { migration_stub(:FirewallRule) }
  let(:reserve_stub)       { MigrationSpecStubs.reserved_stub }

  migration_context :up do
    it "Migrates Reserves data to columns on FirewallRule" do
      fr = firewall_rule_stub.create!
      reserve_stub.create!(
        :resource_type => "FirewallRule",
        :resource_id   => fr.id,
        :reserved      => {
          :ems_ref          => "10075435-0ef2-4b46-aa10-0b78f70715d9",
          :network_protocol => "IPV4"
        }
      )

      migrate

      # Expect counts
      expect(reserve_stub.count).to       eq(0)
      expect(firewall_rule_stub.count).to eq(1)

      # Expect data
      expect(fr.reload.ems_ref).to eq("10075435-0ef2-4b46-aa10-0b78f70715d9")
      expect(fr.reload.network_protocol).to eq("IPV4")

    end
  end

  migration_context :down do
    it "Migrates Reserves data to Reserves table" do
      data = {
        :ems_ref          => "10075435-0ef2-4b46-aa10-0b78f70715d9",
        :network_protocol => "IPV4"
      }

      fr = firewall_rule_stub.create!(data)

      migrate

      # Expect counts
      expect(reserve_stub.count).to       eq(1)
      expect(firewall_rule_stub.count).to eq(1)

      # Expect data
      r = reserve_stub.first
      expect(r.resource_id).to    eq(fr.id)
      expect(r.resource_type).to  eq("FirewallRule")
      expect(r.reserved).to       eq(data)
    end
  end
end

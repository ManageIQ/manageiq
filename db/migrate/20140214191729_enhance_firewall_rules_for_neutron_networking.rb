class EnhanceFirewallRulesForNeutronNetworking < ActiveRecord::Migration
  class FirewallRule < ActiveRecord::Base
    include ReservedMixin
    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def up
    add_column :firewall_rules, :ems_ref, :string
    add_column :firewall_rules, :network_protocol, :string
    rename_column :firewall_rules, :protocol, :host_protocol

    say_with_time("Migrate ems_ref and network_protocol from reserved table") do
      FirewallRule.includes(:reserved_rec).each do |fr|
        fr.reserved_hash_migrate(:ems_ref, :network_protocol)
      end
    end
  end

  def down
    say_with_time("Migrating ems_ref and network_protocol to Reserves table") do
      FirewallRule.includes(:reserved_rec).each do |d|
        d.reserved_hash_set(:ems_ref, d.ems_ref)
        d.reserved_hash_set(:network_protocol, d.network_protocol)
        d.save!
      end
    end

    remove_column :firewall_rules, :ems_ref
    remove_column :firewall_rules, :network_protocol
    rename_column :firewall_rules, :host_protocol, :protocol
  end
end

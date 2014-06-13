class ChangeFirewallRulesToPolymorphic < ActiveRecord::Migration
  class FirewallRule < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    change_table :firewall_rules do |t|
      t.belongs_to :resource, :polymorphic => true
      t.index      [:resource_id, :resource_type]
    end

    say_with_time("Migrating operating_system_id to polymorphic columns") do
      FirewallRule.update_all("resource_type = 'OperatingSystem', resource_id = operating_system_id")
    end

    change_table :firewall_rules do |t|
      t.remove_index      :operating_system_id
      t.remove_belongs_to :operating_system
    end
  end

  def down
    change_table :firewall_rules do |t|
      t.belongs_to :operating_system
      t.index      :operating_system_id
    end

    say_with_time("Migrating polymorphic columns to operating_system_id") do
      resource_type = FirewallRule.arel_table[:resource_type]
      FirewallRule.delete_all(resource_type.not_eq("OperatingSystem"))
      FirewallRule.update_all("operating_system_id = resource_id")
    end

    change_table :firewall_rules do |t|
      t.remove_index      [:resource_id, :resource_type]
      t.remove_belongs_to :resource, :polymorphic => true
    end
  end
end

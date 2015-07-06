class AddSourceSecurityGroupIdAndRangeToFirewallRules < ActiveRecord::Migration
  def change
    add_column :firewall_rules, :source_security_group_id, :bigint
    add_column :firewall_rules, :source_ip_range,          :string
  end
end

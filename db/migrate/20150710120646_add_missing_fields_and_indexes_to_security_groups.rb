class AddMissingFieldsAndIndexesToSecurityGroups < ActiveRecord::Migration
  def change
    add_index  :security_groups, :ems_id
    add_index  :security_groups, :cloud_tenant_id
    add_index  :security_groups, :cloud_network_id
    add_index  :security_groups, :orchestration_stack_id
  end
end

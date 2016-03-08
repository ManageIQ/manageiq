class RemoveSecurityProtocolFromEms < ActiveRecord::Migration[5.0]
  def up
    remove_column :ext_management_systems, :security_protocol
  end

  def down
    add_column :ext_management_systems, :security_protocol, :string
  end
end

class AddSecurityProtocolToEndpoints < ActiveRecord::Migration[5.0]
  def change
    add_column :endpoints, :security_protocol, :string
  end
end

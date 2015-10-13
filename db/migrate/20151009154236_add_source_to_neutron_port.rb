class AddSourceToNeutronPort < ActiveRecord::Migration
  def change
    add_column :network_ports, :source, :string
  end
end

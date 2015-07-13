class AddContainerPortConfigNames < ActiveRecord::Migration
  def change
    add_column :container_port_configs, :name, :string
  end
end

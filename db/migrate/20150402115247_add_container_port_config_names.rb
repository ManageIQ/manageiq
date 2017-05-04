class AddContainerPortConfigNames < ActiveRecord::Migration[4.2]
  def change
    add_column :container_port_configs, :name, :string
  end
end

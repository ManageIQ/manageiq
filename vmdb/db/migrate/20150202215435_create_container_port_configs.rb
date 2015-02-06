class CreateContainerPortConfigs < ActiveRecord::Migration
  def up
    create_table :container_port_configs do |t|
      t.string     :ems_ref
      t.integer    :port
      t.integer    :host_port
      t.string     :protocol
      t.belongs_to :container_definition, :type => :bigint
    end
  end

  def down
    drop_table :container_port_configs
  end
end

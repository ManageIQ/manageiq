class CreateContainerRoutes < ActiveRecord::Migration
  def up
    create_table :container_routes do |t|
      t.string     :ems_ref
      t.string     :name
      t.timestamp  :creation_timestamp, :null => true
      t.string     :resource_version
      t.string     :namespace
      t.string     :host_name
      t.string     :service_name
      t.string     :path
      t.belongs_to :ems, :type => :bigint
    end
    add_index :container_routes, :ems_id
  end

  def down
    remove_index :container_routes, :ems_id
    drop_table :container_routes
  end
end

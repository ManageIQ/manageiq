class CreateKubernetesServices < ActiveRecord::Migration
  def up
    create_table :container_services do |t|
      t.string     :ems_ref
      t.string     :name
      t.timestamp  :creation_timestamp
      t.string     :resource_version
      t.string     :namespace
      t.string     :session_affinity
      t.string     :portal_ip
      t.string     :protocol
      t.integer    :container_port
      t.integer    :port
      t.belongs_to :ems, :type => :bigint
    end

    add_index :container_services, :ems_id
  end

  def down
    remove_index :container_services, :ems_id
    drop_table :container_services
  end
end

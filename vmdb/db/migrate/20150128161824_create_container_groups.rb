class CreateContainerGroups < ActiveRecord::Migration
  def up
    create_table :container_groups do |t|
      t.string     :ems_ref
      t.string     :name
      t.timestamp  :creation_timestamp
      t.string     :namespace
      t.string     :resource_version
      t.string     :restart_policy
      t.string     :dns_policy
      t.belongs_to :ems, :type => :bigint
    end

    add_index :container_groups, :ems_id
  end

  def down
    remove_index :container_groups, :ems_id
    drop_table :container_groups
  end
end

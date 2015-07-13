class CreateContainerProjects < ActiveRecord::Migration
  def up
    create_table :container_projects do |t|
      t.string     :ems_ref
      t.string     :name
      t.timestamp  :creation_timestamp
      t.string     :resource_version
      t.string     :display_name
      t.belongs_to :ems, :type => :bigint
    end
    add_index :container_projects, :ems_id
  end

  def down
    remove_index :container_projects, :ems_id
    drop_table :container_projects
  end
end

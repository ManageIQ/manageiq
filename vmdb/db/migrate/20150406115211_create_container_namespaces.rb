class CreateContainerNamespaces < ActiveRecord::Migration
  def up
    create_table :container_namespaces do |t|
      t.string     :ems_ref
      t.string     :name
      t.timestamp  :creation_timestamp
      t.string     :resource_version
      t.string     :phase
      t.belongs_to :ems, :type => :bigint
    end
  end

  def down
    drop_table :container_namespaces
  end
end

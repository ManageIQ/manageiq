class CreateContainers < ActiveRecord::Migration
  def up
    create_table :containers do |t|
      t.string     :ems_ref
      t.integer    :restart_count
      t.string     :state
      t.string     :name
      t.string     :image
      t.string     :container_id
      t.belongs_to :container_group, :type => :bigint
    end
  end

  def down
    drop_table :containers
  end
end

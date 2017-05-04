class CreateContainerDefinitions < ActiveRecord::Migration[4.2]
  def up
    create_table :container_definitions do |t|
      t.string     :ems_ref
      t.string     :name
      t.string     :image
      t.string     :image_pull_policy
      t.string     :memory
      t.float      :cpu_cores
      t.belongs_to :container_group, :type => :bigint
    end
  end

  def down
    drop_table :container_definitions
  end
end

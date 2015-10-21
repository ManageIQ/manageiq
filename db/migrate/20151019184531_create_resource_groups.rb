class CreateResourceGroups < ActiveRecord::Migration
  def up
    create_table :resource_groups do |t|
      t.string :name
      t.string :ems_ref
      t.bigint :ems_id
      t.string :type
      t.timestamps :null => false
    end
  end

  def down
    drop_table :resource_groups
  end
end

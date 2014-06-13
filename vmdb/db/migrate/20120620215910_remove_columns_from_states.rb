class RemoveColumnsFromStates < ActiveRecord::Migration
  def up
    remove_index :states, :scantype
    remove_index :states, :timestamp
    remove_index :states, [:resource_id, :resource_type]

    remove_column :states, :name
    remove_column :states, :created_on
    remove_column :states, :stats
    remove_column :states, :scantype
    remove_column :states, :xml_data
    remove_column :states, :md5

    add_index :states, [:resource_id, :resource_type, :timestamp]
  end

  def down
    remove_index :states, [:resource_id, :resource_type, :timestamp]

    add_column :states, :name,       :string
    add_column :states, :created_on, :timestamp
    add_column :states, :stats,      :text
    add_column :states, :scantype,   :string
    add_column :states, :xml_data,   :text
    add_column :states, :md5,        :string

    add_index :states, :scantype
    add_index :states, :timestamp
    add_index :states, [:resource_id, :resource_type]
  end
end

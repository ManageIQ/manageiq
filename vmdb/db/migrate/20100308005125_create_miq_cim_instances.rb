class CreateMiqCimInstances < ActiveRecord::Migration
  def self.up
    create_table :miq_cim_instances do |t|
      t.column :class_name,       :string
      t.column :class_hier,       :text
      t.column :namespace,        :string
      t.column :obj_name_str,       :string
      t.column :obj_name,         :text
      t.column :obj,            :text
      t.column :last_update_status,   :integer
      t.column :is_top_managed_element, :boolean
      t.column :top_managed_element_id, :integer
      t.column :agent_top_id,       :integer
      t.column :agent_id,         :integer
      t.column :stat_id,          :integer
      t.column :stat_top_id,        :integer
      t.timestamps
    end
    add_index :miq_cim_instances, :top_managed_element_id
    add_index :miq_cim_instances, :agent_top_id
    add_index :miq_cim_instances, :agent_id
    add_index :miq_cim_instances, :stat_id
    add_index :miq_cim_instances, :stat_top_id
  end

  def self.down
    remove_index :miq_cim_instances, :top_managed_element_id
    remove_index :miq_cim_instances, :agent_top_id
    remove_index :miq_cim_instances, :agent_id
    remove_index :miq_cim_instances, :stat_id
    remove_index :miq_cim_instances, :stat_top_id
    drop_table :miq_cim_instances
  end
end

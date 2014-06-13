class CreateMiqCimAssociations < ActiveRecord::Migration
  def self.up
    create_table :miq_cim_associations do |t|
      t.column :assoc_class,      :string
      t.column :result_class,     :string
      t.column :role,         :string
      t.column :result_role,      :string
      t.column :obj_name,       :string
      t.column :result_obj_name,    :string
      t.column :miq_cim_instance_id,  :integer
      t.column :result_instance_id, :integer
      t.timestamps
    end
    add_index :miq_cim_associations, :miq_cim_instance_id
    add_index :miq_cim_associations, :result_instance_id
  end

  def self.down
    remove_index :miq_cim_associations, :miq_cim_instance_id
    remove_index :miq_cim_associations, :result_instance_id
    drop_table :miq_cim_associations
  end
end

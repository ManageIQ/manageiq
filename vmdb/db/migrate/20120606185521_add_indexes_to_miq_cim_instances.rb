class AddIndexesToMiqCimInstances < ActiveRecord::Migration
  def change
    add_index :miq_cim_instances, :obj_name_str, :unique => true
    add_index :miq_cim_instances, :type
  end
end

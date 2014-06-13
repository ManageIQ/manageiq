class AddTypeSpecObjToMiqCimInstances < ActiveRecord::Migration
  def self.up
    add_column :miq_cim_instances, :type_spec_obj, :text
  end

  def self.down
    remove_column :miq_cim_instances, :type_spec_obj
  end
end

class AddIndexesToMiqCimAssociations < ActiveRecord::Migration
  def change
    add_index :miq_cim_associations, [:obj_name, :result_obj_name, :assoc_class],
              :name => :index_on_miq_cim_associations_for_point_to_point
    add_index :miq_cim_associations, [:miq_cim_instance_id, :assoc_class, :role, :result_role],
              :name => :index_on_miq_cim_associations_for_gen_query
  end
end

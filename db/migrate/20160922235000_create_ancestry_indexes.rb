class CreateAncestryIndexes < ActiveRecord::Migration[5.0]
  def change
    add_index :relationships, 'ancestry varchar_pattern_ops', :name => "index_relationships_on_ancestry_vpo"
    add_index :orchestration_stacks, 'ancestry varchar_pattern_ops', :name => "index_orchestration_stacks_on_ancestry_vpo"
    add_index :services, 'ancestry varchar_pattern_ops', :name => "index_services_on_ancestry_vpo"
    add_index :tenants, 'ancestry varchar_pattern_ops', :name => "index_tenants_on_ancestry_vpo"
  end
end

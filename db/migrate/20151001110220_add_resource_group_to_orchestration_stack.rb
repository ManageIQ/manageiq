class AddResourceGroupToOrchestrationStack < ActiveRecord::Migration
  def change
    add_column :orchestration_stacks, :resource_group, :string
  end
end

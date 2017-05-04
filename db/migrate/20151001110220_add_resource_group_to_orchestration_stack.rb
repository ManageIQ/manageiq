class AddResourceGroupToOrchestrationStack < ActiveRecord::Migration[4.2]
  def change
    add_column :orchestration_stacks, :resource_group, :string
  end
end

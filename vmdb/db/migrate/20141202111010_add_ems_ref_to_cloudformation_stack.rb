class AddEmsRefToCloudformationStack < ActiveRecord::Migration
  def up
    change_column :orchestration_stacks, :ems_ref, :text
    add_column :orchestration_stack_parameters, :ems_ref, :text
    add_column :orchestration_stack_resources, :ems_ref, :text
    add_column :orchestration_stack_outputs, :ems_ref, :text
  end

  def down
    change_column :orchestration_stacks, :ems_ref, :string
    remove_column :orchestration_stack_parameters, :ems_ref
    remove_column :orchestration_stack_resources, :ems_ref
    remove_column :orchestration_stack_outputs, :ems_ref
  end
end

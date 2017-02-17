class AddTimesToOrchestrationStackResources < ActiveRecord::Migration[5.0]
  def change
    add_column :orchestration_stack_resources, :start_time,  :timestamp
    add_column :orchestration_stack_resources, :finish_time, :timestamp
  end
end

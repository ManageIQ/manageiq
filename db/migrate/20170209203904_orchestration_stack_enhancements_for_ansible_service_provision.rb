class OrchestrationStackEnhancementsForAnsibleServiceProvision < ActiveRecord::Migration[5.0]
  def change
    add_column :orchestration_stacks, :start_time,                   :timestamp
    add_column :orchestration_stacks, :finish_time,                  :timestamp
    add_column :orchestration_stacks, :configuration_script_base_id, :bigint
    add_column :orchestration_stacks, :verbosity,                    :integer
    add_column :orchestration_stacks, :hosts,                        :text, :array => true
  end
end

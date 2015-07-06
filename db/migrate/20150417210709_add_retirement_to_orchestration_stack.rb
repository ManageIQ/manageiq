class AddRetirementToOrchestrationStack < ActiveRecord::Migration
  def change
    add_column :orchestration_stacks, :retired,              :boolean
    add_column :orchestration_stacks, :retires_on,           :date
    add_column :orchestration_stacks, :retirement_warn,      :bigint
    add_column :orchestration_stacks, :retirement_last_warn, :datetime
    add_column :orchestration_stacks, :retirement_state,     :string
    add_column :orchestration_stacks, :retirement_requester, :string
  end
end

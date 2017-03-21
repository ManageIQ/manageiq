class RemoveAgentStateFromJobs < ActiveRecord::Migration[5.0]
  def change
    remove_column :jobs, :agent_state, :string
  end
end

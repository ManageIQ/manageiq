class RemoveAgentIdFromJobs < ActiveRecord::Migration[5.0]
  def change
    remove_column :jobs, :agent_id, :bigint
  end
end

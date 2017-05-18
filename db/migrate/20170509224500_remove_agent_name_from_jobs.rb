class RemoveAgentNameFromJobs < ActiveRecord::Migration[5.0]
  def change
    remove_column :jobs, :agent_name, :string
  end
end

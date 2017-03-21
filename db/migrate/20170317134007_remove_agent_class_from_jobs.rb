class RemoveAgentClassFromJobs < ActiveRecord::Migration[5.0]
  def change
    remove_column :jobs, :agent_class, :string
  end
end

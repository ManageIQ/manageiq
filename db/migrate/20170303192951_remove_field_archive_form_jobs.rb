class RemoveFieldArchiveFormJobs < ActiveRecord::Migration[5.0]
  def change
    remove_column :jobs, :archive, :boolean
  end
end

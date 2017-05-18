class RemoveProcessColumnFromJobs < ActiveRecord::Migration[5.0]
  def change
    remove_column :jobs, :process, :bytea
  end
end

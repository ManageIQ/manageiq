class RemoveFieldCodeFromJobs < ActiveRecord::Migration[5.0]
  def change
    remove_column :jobs, :code, :string
  end
end

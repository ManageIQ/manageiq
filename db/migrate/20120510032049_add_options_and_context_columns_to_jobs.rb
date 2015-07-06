class AddOptionsAndContextColumnsToJobs < ActiveRecord::Migration
  def change
    add_column :jobs, :options, :text
    add_column :jobs, :context, :text
  end
end

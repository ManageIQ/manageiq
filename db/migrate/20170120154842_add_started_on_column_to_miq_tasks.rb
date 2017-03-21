class AddStartedOnColumnToMiqTasks < ActiveRecord::Migration[5.0]
  def change
    add_column :miq_tasks, :started_on, :datetime
    add_column :miq_tasks, :zone, :string
  end
end

class AddMiqRequestTaskIdToMiqRequestTask < ActiveRecord::Migration
  def change
    add_column :miq_request_tasks, :miq_request_task_id, :bigint
  end
end

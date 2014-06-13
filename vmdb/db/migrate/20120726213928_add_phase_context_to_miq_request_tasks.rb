class AddPhaseContextToMiqRequestTasks < ActiveRecord::Migration
  def change
    add_column :miq_request_tasks, :phase_context, :text
  end
end

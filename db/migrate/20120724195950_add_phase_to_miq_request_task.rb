class AddPhaseToMiqRequestTask < ActiveRecord::Migration
  def change
    add_column :miq_request_tasks, :phase, :string
  end
end

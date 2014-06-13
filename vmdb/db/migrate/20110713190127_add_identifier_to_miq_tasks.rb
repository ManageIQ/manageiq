class AddIdentifierToMiqTasks < ActiveRecord::Migration
  def self.up
    add_column      :miq_tasks, :identifier,  :string
  end

  def self.down
    remove_column   :miq_tasks, :identifier
  end
end

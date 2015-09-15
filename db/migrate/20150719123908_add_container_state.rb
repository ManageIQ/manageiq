class AddContainerState < ActiveRecord::Migration
  def change
    add_column :containers, :reason, :string
    add_column :containers, :started_at, :datetime
    add_column :containers, :finished_at, :datetime
    add_column :containers, :exit_code, :integer
    add_column :containers, :signal, :integer
    add_column :containers, :message, :string
    add_column :containers, :last_state, :string
    add_column :containers, :last_reason, :string
    add_column :containers, :last_started_at, :datetime
    add_column :containers, :last_finished_at, :datetime
    add_column :containers, :last_exit_code, :integer
    add_column :containers, :last_signal, :integer
    add_column :containers, :last_message, :string
  end
end

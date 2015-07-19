class AddContainerState < ActiveRecord::Migration
  def change
    add_column :containers, :reason, :string
    add_column :containers, :started_at, :string
    add_column :containers, :finished_at, :string
    add_column :containers, :exit_code, :integer
    add_column :containers, :signal, :integer
    add_column :containers, :message, :string
    add_column :containers, :last_state, :string
    add_column :containers, :last_state_reason, :string
    add_column :containers, :last_state_started_at, :string
    add_column :containers, :last_state_finished_at, :string
    add_column :containers, :last_state_exit_code, :integer
    add_column :containers, :last_state_signal, :integer
    add_column :containers, :last_state_message, :string
  end
end

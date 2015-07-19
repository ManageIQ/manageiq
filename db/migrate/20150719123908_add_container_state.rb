class AddContainerState < ActiveRecord::Migration
  def change
    add_column :containers, :reason, :string
    add_column :containers, :started_at, :string
    add_column :containers, :finished_at, :string
    add_column :containers, :exit_code, :integer
    add_column :containers, :signal, :integer
    add_column :containers, :message, :string
  end
end

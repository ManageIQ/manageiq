class AddContainerGroupPhase < ActiveRecord::Migration
  def change
    add_column :container_groups, :phase, :string
    add_column :container_groups, :message, :string
    add_column :container_groups, :reason, :string
  end
end

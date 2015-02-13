class CreateConfiguredSystemLastCheckin < ActiveRecord::Migration
  def change
    add_column :configured_systems, :last_checkin, :timestamp
    add_column :configured_systems, :build_state, :string
  end
end

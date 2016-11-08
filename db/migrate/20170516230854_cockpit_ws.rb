class CockpitWs < ActiveRecord::Migration[5.0]
  def change
    add_column :miq_servers, :has_active_cockpit_ws, :boolean
  end
end

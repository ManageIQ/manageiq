class AddZoneIdToMiqSmisAgent < ActiveRecord::Migration
  def self.up
    add_column :miq_smis_agents, :zone_id, :integer
  end

  def self.down
    remove_column :miq_smis_agents, :zone_id
  end
end

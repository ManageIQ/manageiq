class SmisConvertIdsTo64bit < ActiveRecord::Migration
  def self.up
    change_column :miq_cim_instances, :vmdb_obj_id, :bigint
    change_column :miq_cim_instances, :zone_id,     :bigint
    change_column :miq_smis_agents,   :zone_id,     :bigint
  end

  def self.down
    change_column :miq_cim_instances, :vmdb_obj_id, :integer
    change_column :miq_cim_instances, :zone_id,     :integer
    change_column :miq_smis_agents,   :zone_id,     :integer
  end
end

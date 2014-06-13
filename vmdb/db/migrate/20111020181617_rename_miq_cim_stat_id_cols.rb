class RenameMiqCimStatIdCols < ActiveRecord::Migration
  def self.up
    remove_index  :miq_cim_derived_stats,       :miq_cim_stat_id
    remove_index  :ontap_volume_derived_stats,  :miq_cim_stat_id

    rename_column :miq_cim_derived_stats,       :miq_cim_stat_id, :miq_storage_stat_id
    rename_column :ontap_volume_derived_stats,  :miq_cim_stat_id, :miq_storage_stat_id

    add_index     :miq_cim_derived_stats,       :miq_storage_stat_id
    add_index     :ontap_volume_derived_stats,  :miq_storage_stat_id
  end

  def self.down
    remove_index  :miq_cim_derived_stats,       :miq_storage_stat_id
    remove_index  :ontap_volume_derived_stats,  :miq_storage_stat_id

    rename_column :miq_cim_derived_stats,       :miq_storage_stat_id, :miq_cim_stat_id
    rename_column :ontap_volume_derived_stats,  :miq_storage_stat_id, :miq_cim_stat_id

    add_index     :miq_cim_derived_stats,       :miq_cim_stat_id
    add_index     :ontap_volume_derived_stats,  :miq_cim_stat_id
  end
end

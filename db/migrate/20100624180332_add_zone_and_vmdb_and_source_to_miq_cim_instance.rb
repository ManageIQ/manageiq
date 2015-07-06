class AddZoneAndVmdbAndSourceToMiqCimInstance < ActiveRecord::Migration
  def self.up
    add_column :miq_cim_instances, :vmdb_obj_id, :integer
    add_column :miq_cim_instances, :vmdb_obj_type, :string
    add_column :miq_cim_instances, :zone_id, :integer
    add_column :miq_cim_instances, :source, :string
  end

  def self.down
    remove_column :miq_cim_instances, :vmdb_obj_id
    remove_column :miq_cim_instances, :vmdb_obj_type
    remove_column :miq_cim_instances, :zone_id
    remove_column :miq_cim_instances, :source
  end
end

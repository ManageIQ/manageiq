class AddStatusToMiqCimAssociations < ActiveRecord::Migration
  def up
    add_column :miq_cim_associations, :status,  :integer
    add_column :miq_cim_associations, :zone_id, :bigint
  end

  def down
    remove_column :miq_cim_associations, :status
    remove_column :miq_cim_associations, :zone_id
  end
end

class RemoveTimestampsFromMiqCimAssociations < ActiveRecord::Migration
  def up
    remove_timestamps :miq_cim_associations
  end

  def down
    add_timestamps :miq_cim_associations
  end
end

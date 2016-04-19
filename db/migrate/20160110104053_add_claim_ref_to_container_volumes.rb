class AddClaimRefToContainerVolumes < ActiveRecord::Migration
  def up
    change_table :container_volumes do |t|
      t.belongs_to :persistent_volume_claim, :type => :bigint
    end
  end

  def down
    change_table :container_volumes do |t|
      t.remove_belongs_to :persistent_volume_claim
    end
  end
end

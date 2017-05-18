class AddClaimRefToContainerVolumes < ActiveRecord::Migration[4.2]
  def change
    change_table :container_volumes do |t|
      t.belongs_to :persistent_volume_claim, :type => :bigint
    end
  end
end

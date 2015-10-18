class CreatePersistentVolumeClaim < ActiveRecord::Migration
  def change
    create_table :persistent_volume_claims do |t|
      t.belongs_to :ems, :type => :bigint
      t.belongs_to :persistent_volume, :type => :bigint
      t.string     :ems_ref
      t.string     :name
      t.timestamp  :ems_created_on
      t.timestamp  :created_on
      t.string     :resource_version
      t.text       :desired_access_modes, :array => true, :default => []
      t.string     :phase
      t.text       :actual_access_modes, :array => true, :default => []
      t.text       :capacity
    end
  end
end

class CreateAvailabilityZones < ActiveRecord::Migration
  def up
    create_table :availability_zones do |t|
      t.belongs_to :ems, :type => :bigint
      t.string     :name
    end

    add_index :availability_zones, :ems_id

    # TODO: Migrate existing cloud values to availability_zones
  end

  def down
    drop_table :availability_zones
  end
end

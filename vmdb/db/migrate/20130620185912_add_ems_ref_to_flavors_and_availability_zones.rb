class AddEmsRefToFlavorsAndAvailabilityZones < ActiveRecord::Migration
  def change
    add_column :flavors,            :ems_ref, :string
    add_column :availability_zones, :ems_ref, :string
  end
end

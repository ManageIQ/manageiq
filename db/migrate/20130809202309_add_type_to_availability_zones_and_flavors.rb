class AddTypeToAvailabilityZonesAndFlavors < ActiveRecord::Migration
  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class AvailabilityZone < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class Flavor < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    add_column :availability_zones, :type, :string
    add_column :flavors,            :type, :string

    ems_ids = {
      "Amazon"    => ExtManagementSystem.where(:type => "EmsAmazon").pluck(:id),
      "Openstack" => ExtManagementSystem.where(:type => "EmsOpenstack").pluck(:id),
    }

    say_with_time("Migrating type column for availability_zones") do
      ems_ids.each do |type, ids|
        AvailabilityZone.where(:ems_id => ids).update_all(:type => "AvailabilityZone#{type}")
      end
    end

    say_with_time("Migrating type column for flavors") do
      ems_ids.each do |type, ids|
        Flavor.where(:ems_id => ids).update_all(:type => "Flavor#{type}")
      end
    end
  end

  def down
    remove_column :availability_zones, :type
    remove_column :flavors,            :type
  end
end

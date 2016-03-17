class RemoveIsDatacenterFromEmsFolder < ActiveRecord::Migration[5.0]
  class EmsFolder < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    # Go through all existing EmsFolder records and set :type => Datacenter
    # if the is_datacenter column is true before deleting it
    say_with_time("Set type column for EmsFolders") do
      EmsFolder.where(:is_datacenter => true).update_all(:type => "Datacenter")
    end

    remove_column :ems_folders, :is_datacenter
  end

  def down
    add_column :ems_folders, :is_datacenter, :boolean

    say_with_time("Set is_datacenter for EmsFolders") do
      EmsFolder.where("type != 'Datacenter' OR type is NULL").update_all(:is_datacenter => false)
      EmsFolder.where(:type => "Datacenter").update_all(:is_datacenter => true)
    end
  end
end

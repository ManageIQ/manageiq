class AddTypeToVdiFarms < ActiveRecord::Migration
  class VdiFarm < ActiveRecord::Base
    self.inheritance_column = :_type_disabled   # disable STI
  end

  def up
    add_column :vdi_farms, :type, :string

    t = VdiFarm.arel_table
    say_with_time("Migrating VdiFarms to vendor specific models") do
      VdiFarm.where(:vendor => 'citrix').update_all(:type => "VdiFarmCitrix")
      VdiFarm.where(t[:vendor].not_eq "citrix").update_all(:type => "VdiFarmVmware")
    end
  end

  def down
    remove_column :vdi_farms, :type
  end
end

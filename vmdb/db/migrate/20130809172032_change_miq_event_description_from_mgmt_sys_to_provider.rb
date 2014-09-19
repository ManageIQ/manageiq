class ChangeMiqEventDescriptionFromMgmtSysToProvider < ActiveRecord::Migration
  class MiqEvent < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    say_with_time("Changing MiqEvent description with Mgmt Sys to Provider") do
      MiqEvent.where("description like ? and name like ?", "Mgmt Sys%", "ems_auth_%").all.each do |e|
        desc = e.description.gsub(/Mgmt Sys/, 'Provider')
        e.update_attributes(:description => desc)
      end
    end
  end

  def down
    say_with_time("Changing MiqEvent description with Provider to Mgmt Sys ") do
      MiqEvent.where("description like ? and name like ?", "Provider%", "ems_auth_%").all.each do |e|
        desc = e.description.gsub(/Provider/, 'Mgmt Sys' )
        e.update_attributes(:description => desc)
      end
    end
  end
end

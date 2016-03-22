class UpdateSwitchUidEms < ActiveRecord::Migration[5.0]
  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
    has_many :hosts,
             :class_name => "UpdateSwitchUidEms::Host",
             :foreign_key => "ems_id"
  end

  class Host < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
    belongs_to :ext_management_system,
               :class_name => "UpdateSwitchUidEms::ExtManagementSystem",
               :foreign_key => "ems_id"
    has_many :switches,
             :class_name => "UpdateSwitchUidEms::Switch"
  end

  class Switch < ActiveRecord::Base
    belongs_to :host,
             :class_name => "UpdateSwitchUidEms::Host"
  end

  def up
    say_with_time("Updating switch uid_ems to be prefixed with ems_guid and host_id") do
      ExtManagementSystem.all.each do |ems|
        ems.hosts.each do |host|
          host.switches.each do |s|
            s.update(:uid_ems => "#{ems.guid}|#{host.ems_ref}|#{s.uid_ems}")
          end
        end
      end
    end
  end

  def down
    Switch.all.each do |s|
      raise "Expected '|' not found in uid_ems" if s.uid_ems.index('|').nil?
      s.update(:uid_ems => s.uid_ems[s.uid_ems.rindex('|') + 1..-1])
    end
  end
end

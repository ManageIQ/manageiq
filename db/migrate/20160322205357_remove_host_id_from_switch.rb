class RemoveHostIdFromSwitch < ActiveRecord::Migration[5.0]
  class Host < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
    has_many :host_switches, :dependent => :destroy, :class_name => 'RemoveHostIdFromSwitch::HostSwitch'
    has_many :switches, :through => :host_switches, :class_name => 'RemoveHostIdFromSwitch::Switch'
  end

  class Switch < ActiveRecord::Base
    has_many :host_switches, :dependent => :destroy, :class_name  => 'RemoveHostIdFromSwitch::HostSwitch'
    has_many :hosts, :through => :host_switches, :class_name  => 'RemoveHostIdFromSwitch::Host'
  end

  class HostSwitch < ActiveRecord::Base
    belongs_to :host, :class_name => 'RemoveHostIdFromSwitch::Host'
    belongs_to :switch, :class_name => 'RemoveHostIdFromSwitch::Switch'
  end

  def up
    remove_column :switches, :host_id, :bigint
  end

  def down
    add_column :switches, :host_id, :bigint
    say_with_time('Populating switches.host_id from host_switches table') do
      Switch.includes(:hosts).find_each do |switch|
        switch.host_id = switch.hosts.first.id
        switch.save!
      end
    end
  end
end

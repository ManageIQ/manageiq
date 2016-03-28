class MoveSwitchHostToJointable < ActiveRecord::Migration[5.0]
  class Host < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
    has_many :switches,
             :class_name => 'MoveSwitchHostToJointable::Switch'

  end

  class Switch < ActiveRecord::Base
    belongs_to :host,
               :class_name => 'MoveSwitchHostToJointable::Host'
  end

  class HostsSwitches < ActiveRecord::Base
  end

  def up
    say_with_time('Populating hosts_switches table with (host.id, switch.id)') do
      Host.all.each do |host|
        host.switches.each do |switch|
          HostsSwitches.create!(:host_id => host.id, :switch_id => switch.id)
        end
      end
    end
  end
end

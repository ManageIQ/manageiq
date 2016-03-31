class FixEventClassForEvmAlertEvent < ActiveRecord::Migration
  class EventStream < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class EmsCluster < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class Host < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class Vm < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    say_with_time("Converting event class for EVMAlertEvent to MiqEvent") do
      EventStream.where(:type => 'EmsEvent', :event_type => 'EVMAlertEvent').each do |event|
        attrs = {:type => 'MiqEvent'}

        if event.ems_cluster_id
          attrs[:target_type] = 'EmsCluster'
          attrs[:target_id]   = event.ems_cluster_id
        elsif event.vm_or_template_id
          attrs[:target_type] = 'VmOrTemplate'
          attrs[:target_id]   = event.vm_or_template_id
        elsif event.host_id && event.vm_or_template_id.nil?
          attrs[:target_type] = 'Host'
          attrs[:target_id]   = event.host_id
        end
        event.update_attributes(attrs)
      end
    end
  end

  def down
    say_with_time("Converting event class for EVMAlertEvent to EmsEvent") do
      EventStream.where(:type => 'MiqEvent', :event_type => 'EVMAlertEvent').update_all(
        :type => 'EmsEvent', :target_id => nil, :target_type => nil
      )
    end
  end
end

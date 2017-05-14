class RemoveContainerGroupFailedSyncEvent < ActiveRecord::Migration[5.0]
  class Relationship < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class MiqEventDefinition < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    say_with_time("Remove event definition containergroup_failedsync") do
      eventdef = MiqEventDefinition.where(:name => 'containergroup_failedsync').first
      if eventdef
        Relationship.where(:resource_type => 'MiqEventDefinition', :resource_id => eventdef.id).delete_all
        eventdef.delete
      end
    end
  end
end

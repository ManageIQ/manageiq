class RemoveVmDiscoverRowFromMiqEventDefinitions < ActiveRecord::Migration
  class Relationship < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class MiqEventDefinition < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    say_with_time("Remove event definition vm_discover") do
      MiqEventDefinition.where(:name => 'vm_discover').each do |eventdef|
        Relationship.where(:resource_type => 'MiqEventDefinition', :resource_id => eventdef.id).delete_all
        eventdef.delete
      end
    end
  end
end

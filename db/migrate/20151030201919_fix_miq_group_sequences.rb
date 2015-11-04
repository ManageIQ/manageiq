class FixMiqGroupSequences < ActiveRecord::Migration
  class MiqGroup < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    MiqGroup.where(:sequence => nil).update_all(:sequence => 1)

    MiqGroup.where(:guid => nil).each do |g|
      g.update_attributes(:guid => MiqUUID.new_guid)
    end
  end
end

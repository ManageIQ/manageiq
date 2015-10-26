class SetMiqGroupsGroupType < ActiveRecord::Migration
  class MiqGroup < ActiveRecord::Base
    USER_GROUP = "user"
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    MiqGroup.where(:group_type => nil).update_all(:group_type => MiqGroup::USER_GROUP)
  end

  def down
    MiqGroup.where(:group_type => MiqGroup::USER_GROUP).update_all(:group_type => nil)
  end
end

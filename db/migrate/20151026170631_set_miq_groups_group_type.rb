class SetMiqGroupsGroupType < ActiveRecord::Migration
  class MiqGroup < ActiveRecord::Base
    USER_GROUP = "user"
  end

  def up
    say_with_time "defaulting groups to user groups" do
      MiqGroup.where(:group_type => nil).update_all(:group_type => MiqGroup::USER_GROUP)
    end
  end

  def down
    say_with_time "rolling back user group changes" do
      MiqGroup.where(:group_type => MiqGroup::USER_GROUP).update_all(:group_type => nil)
    end
  end
end

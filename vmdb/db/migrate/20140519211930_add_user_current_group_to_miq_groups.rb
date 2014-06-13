class AddUserCurrentGroupToMiqGroups < ActiveRecord::Migration
  class User < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI

    belongs_to :current_group, :class_name => "AddUserCurrentGroupToMiqGroups::MiqGroup"
    has_and_belongs_to_many :miq_groups, :class_name => "AddUserCurrentGroupToMiqGroups::MiqGroup"
  end

  class MiqGroup < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    say_with_time("Migrating current_group into user's miq_groups") do
      User.where("current_group_id IS NOT NULL").each do |u|
        u.miq_groups << u.current_group unless u.miq_groups.include?(u.current_group)
      end
    end
  end
end

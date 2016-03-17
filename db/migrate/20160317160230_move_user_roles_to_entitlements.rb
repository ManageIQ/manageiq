class MoveUserRolesToEntitlements < ActiveRecord::Migration[5.0]
  class MiqGroup < ActiveRecord::Base; end
  class Entitlement < ActiveRecord::Base; end

  def up
    MiqGroup.find_each do |group|
      Entitlement.create!(:miq_group_id => group.id, :miq_user_role_id => group.miq_user_role_id)
    end
  end

  def down
    MiqGroup.find_each do |group|
      Entitlement.delete_all(:miq_group_id => group.id)
    end
  end
end

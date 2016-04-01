class RemoveMiqUserRoleFromMiqGroups < ActiveRecord::Migration[5.0]
  class MiqGroup < ActiveRecord::Base
    has_one :entitlement, :class_name => RemoveMiqUserRoleFromMiqGroups::Entitlement
  end

  class Entitlement < ActiveRecord::Base
    belongs_to :miq_group,     :class_name => RemoveMiqUserRoleFromMiqGroups::MiqGroup
    belongs_to :miq_user_role, :class_name => RemoveMiqUserRoleFromMiqGroups::MiqUserRole
  end

  class MiqUserRole < ActiveRecord::Base
    has_many :entitlements, :class_name => RemoveMiqUserRoleFromMiqGroups::Entitlement
  end

  def up
    remove_column :miq_groups, :miq_user_role_id
  end

  def down
    add_column :miq_groups, :miq_user_role_id, :bigint

    MiqGroup.includes(:entitlement).where.not(:entitlements => {:miq_user_role_id => nil}).find_each do |group|
      group.miq_user_role_id = group.entitlement.miq_user_role_id
      group.save!
    end
  end
end

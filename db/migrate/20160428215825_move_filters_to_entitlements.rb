class MoveFiltersToEntitlements < ActiveRecord::Migration[5.0]
  class MiqGroup < ActiveRecord::Base
    has_one :entitlement, :class_name => 'MoveFiltersToEntitlements::Entitlement'
    serialize :filters
  end

  class Entitlement < ActiveRecord::Base
    belongs_to :miq_group, :class_name => 'MoveFiltersToEntitlements::MiqGroup'
    serialize :filters
  end

  def up
    say_with_time 'Moving MiqGroup filters to Entitlements' do
      MiqGroup.find_each do |group|
        if group.filters && group.entitlement
          group.entitlement.filters = group.filters
          group.entitlement.save!
        end
      end
    end
  end

  def down
    say_with_time 'Moving Entitlement filters back to MiqGroups' do
      Entitlement.find_each do |entitlement|
        if entitlement.filters && entitlement.miq_group
          entitlement.miq_group.filters = entitlement.filters
          entitlement.miq_group.save!
        end
      end
    end
  end
end

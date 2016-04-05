class MoveFiltersToEntitlements < ActiveRecord::Migration[5.0]
  class Entitlement < ActiveRecord::Base
    belongs_to :miq_group, :class_name => "MoveFiltersToEntitlements::MiqGroup"
  end

  class MiqGroup < ActiveRecord::Base
    has_one :entitlement, :class_name => "MoveFiltersToEntitlements::Entitlement"

    serialize :filters
  end

  def up
    MiqGroup.find_each do |group|
      if group.filters.present?
        if group.filters["managed"].present?
          group.entitlement ||= Entitlement.new
          group.entitlement.tag_filters = group.filters["managed"]
        end

        if group.filters["belongsto"].present?
          group.entitlement ||= Entitlement.new
          group.entitlement.resource_filters = group.filters["belongsto"]
        end

        group.filters = nil
        group.entitlement.save!
        group.save!
      end
    end
  end

  def down
    Entitlement.find_each do |entitlement|
      if entitlement.miq_group && (entitlement.tag_filters.present? || entitlement.resource_filters.present?)
        group = entitlement.miq_group

        group.filters = {"managed" => entitlement.tag_filters, "belongsto" => entitlement.resource_filters}
        group.save!

        entitlement.tag_filters      = []
        entitlement.resource_filters = []
        entitlement.save!
      end
    end
  end
end

class Entitlement < ApplicationRecord
  belongs_to :miq_group
  belongs_to :miq_user_role

  def self.remove_tag_filters_by_name!(tag_name)
    find_each do |entitlement|
      entitlement.tag_filters.reject! { |t| t == tag_name }
      entitlement.save
    end
  end
end

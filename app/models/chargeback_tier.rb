class ChargebackTier < ActiveRecord::Base
  include UuidMixin
  include ReportableMixin

  ASSIGNMENT_PARENT_ASSOCIATIONS = [:host, :ems_cluster, :storage, :ext_management_system, :my_enterprise]
  include AssignmentMixin
  has_many :chargeback_tier_details, :dependent => :destroy

  def rate(value)
    ratet = 0
    ChargebackTierDetail.where(:chargeback_tier_id => id).each do |tier_detail|
      if value >= tier_detail.start
        ratet = rate_above
        if value < tier_detail.end
          ratet = tier_detail.tier_rate.to_f
          return ratet
        end
      else
        ratet = rate_below
      end
    end
    ratet
  end

  def self.all_names
    a = ["Not tiered"]
    ChargebackTier.all.to_a.each do |tier|
      a.append(tier.name)
    end
    a
  end

  def self.all_ids
    a = ["Not tiered"]
    ChargebackTier.all.to_a.each do |tier|
      a.append(tier.id)
    end
    a
  end

  def self.find_by_name(name)
    ChargebackTier.find_by_name(name)
  end
end

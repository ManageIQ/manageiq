class ChargebackTier < ActiveRecord::Base
  has_many :chargeback_tier_detail, :dependent => :destroy

  def rate(value)
    ChargebackTierDetail.where(chargeback_tier: self.id).find_each do |tier_detail|
      if value>=tier_detail.start
        rate = self.rate_above
        if value<tier_detail.end
          rate = tier_detail.rate
          break
        end
      else
        rate = self.rate_below
      end
    end
  end

  def self.allNames
    a = ["Not tiered"]
    ChargebackTier.all.to_a.each do |tier|
      a.append(tier.name)
    end
    a
  end

  def self.allIds
    a = ["Not tiered"]
    ChargebackTier.all.to_a.each do |tier|
      a.append(tier.id)
    end
    a
  end

  def self.find_by_name(name)
    ChargebackTier.where(name: name).take
  end
end

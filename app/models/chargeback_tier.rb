class ChargebackTier < ActiveRecord::Base
  has_many :chargeback_tier_detail, :dependent => :destroy

  def rate(value)
    ChargebackTierDetail.where(chargeback_tier_id: self.guid).find_each do |tier_detail|
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
end

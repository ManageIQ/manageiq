class ChargebackTier < ActiveRecord::Base
  has_many :chargeback_tier_detail
end

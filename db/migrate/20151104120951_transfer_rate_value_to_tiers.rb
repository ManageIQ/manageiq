class TransferRateValueToTiers < ActiveRecord::Migration
  class ChargebackRateDetail < ActiveRecord::Base
    has_many :chargeback_tiers
  end
  class ChargebackTier < ActiveRecord::Base
    belongs_to :chargeback_rate_detail
  end

  def change
    ChargebackRateDetail.reset_column_information
    ChargebackRateDetail.all.to_a.each do |detail|
      if detail.respond_to?(:rate)
        ChargebackTier.create(:chargeback_rate_detail_id => detail.id,
                              :start                     => 0,
                              :end                       => Float::INFINITY,
                              :fixed_rate                => 0.0,
                              :variable_rate             => detail.rate)
      end
    end
  end
end

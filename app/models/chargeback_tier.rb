class ChargebackTier < ApplicationRecord
  belongs_to :chargeback_rate_detail
  validates :fixed_rate, :variable_rate, :start, :end, :numericality => true

  def self.to_float(s)
    if s.to_s.include?("Infinity")
      Float::INFINITY
    else
      s
    end
  end
end

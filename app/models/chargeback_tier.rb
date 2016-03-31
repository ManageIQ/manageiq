class ChargebackTier < ApplicationRecord
  belongs_to :chargeback_rate_detail
  validates :fixed_rate, :variable_rate, :start, :end, :numericality => true
  validates :start, :numericality => {:greater_than_or_equal_to => 0, :less_than => Float::INFINITY}
  validates :end,   :numericality => {:greater_than_or_equal_to => 0}

  def self.to_float(s)
    if s.to_s.include?("Infinity")
      Float::INFINITY
    else
      s
    end
  end

  def starts_with_zero?
    start.zero?
  end

  def ends_with_infinity?
    self.end == Float::INFINITY
  end
end
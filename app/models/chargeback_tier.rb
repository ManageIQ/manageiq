class ChargebackTier < ApplicationRecord
  belongs_to :chargeback_rate_detail
  validates :fixed_rate, :variable_rate, :numericality => true
  validates :start,  :numericality => {:greater_than_or_equal_to => 0, :less_than => Float::INFINITY}
  validates :finish, :numericality => {:greater_than_or_equal_to => 0}

  FORM_ATTRIBUTES = %i(fixed_rate variable_rate start finish).freeze

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
    finish == Float::INFINITY
  end
end
class ChargebackTier < ApplicationRecord
  belongs_to :chargeback_rate_detail
  validates :fixed_rate, :variable_rate, :numericality => true
  validates :start,  :numericality => {:greater_than_or_equal_to => 0, :less_than => Float::INFINITY}
  validates :finish, :numericality => {:greater_than_or_equal_to => 0}
  validate :continuity?

  default_scope { order(:start => :asc) }

  FORM_ATTRIBUTES = %i(fixed_rate variable_rate start finish).freeze

  def self.to_float(s)
    if s.to_s.include?("Infinity")
      Float::INFINITY
    else
      s
    end
  end

  def includes?(value)
    starts_with_zero? && value.zero? || value > start && value.to_f <= finish
  end

  def starts_with_zero?
    start.zero?
  end

  def ends_with_infinity?
    finish == Float::INFINITY
  end

  def gratis?
    fixed_rate.zero? && variable_rate.zero?
  end

  def continuity?
    is_continuous = start < finish
    errors.add(:finish, "value must be greater than start value.") unless is_continuous
    is_continuous
  end
end

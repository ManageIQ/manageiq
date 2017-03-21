class ShowbackCharge < ApplicationRecord
  belongs_to :showback_bucket
  belongs_to :showback_event
  validates :showback_bucket,  presence: true, allow_nil: false
  validates :showback_event, presence: true, allow_nil: false
  validate  :fixed_cost_big_decimal, :variable_cost_big_decimal

  def fixed_cost_big_decimal
    unless fixed_cost.nil?
      self.fixed_cost = self.fixed_cost.to_d
      errors.add(:fixed_cost, "must be of class money") unless fixed_cost.class == BigDecimal
    end
  end

  def variable_cost_big_decimal
    unless variable_cost.nil?
      variable_cost = variable_cost.to_d
      errors.add(:variable_cost, "must be of class money") unless variable_cost.class == BigDecimal
    end
  end
end

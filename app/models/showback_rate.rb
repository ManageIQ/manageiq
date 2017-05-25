class ShowbackRate < ApplicationRecord
  belongs_to :showback_tariff
  validates :fixed_cost,                                       :presence => true
  validates :variable_cost,                                    :presence => true
  validates :concept,                                          :presence => true
  validate  :fixed_cost_big_decimal, :variable_cost_big_decimal

  def fixed_cost_big_decimal
    if fixed_cost
      self.fixed_cost = BigDecimal.new(self.fixed_cost)
      errors.add(:fixed_cost, "must be of class money") unless fixed_cost.class == BigDecimal
    end
  end

  def variable_cost_big_decimal
    if variable_cost
      self.variable_cost = BigDecimal.new(self.variable_cost)
      errors.add(:variable_cost, "must be of class money") unless variable_cost.class == BigDecimal
    end
  end
end

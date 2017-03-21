class ShowbackRate < ApplicationRecord
  validates :fixed_cost,                                       :presence => true
  validates :variable_cost,                                    :presence => true
  validates :concept,                                          :presence => true
  validate  :check_type_fixed_cost, :check_type_variable_cost, :on       => :create

  def check_type_fixed_cost
    errors.add(:fixed_cost, "fixed_cost must be a class of BigDecimal") unless fixed_cost.class == BigDecimal
  end

  def check_type_variable_cost
    errors.add(:variable_cost, "variable_cost must a class of BigDecimal") unless variable_cost.class == BigDecimal
  end
end

class ChargeableFieldBudget < ApplicationRecord
  belongs_to :chargeable_field
  belongs_to :budget
end

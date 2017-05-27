class ShowbackCharge < ApplicationRecord
  belongs_to :showback_bucket, :inverse_of => :showback_charges
  belongs_to :showback_event, :inverse_of => :showback_charges
  validates :showback_bucket, :presence => true, :allow_nil => false
  validates :showback_event, :presence => true, :allow_nil => false
  monetize :fixed_cost_cents
  monetize :variable_cost_cents
end

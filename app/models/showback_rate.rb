class ShowbackRate < ApplicationRecord
  belongs_to :showback_price_plan, :inverse_of => :showback_rates

  monetize :fixed_rate_cents
  monetize :variable_rate_cents
  validates :calculation,        :presence  => true
  validates :category,           :presence  => true
  validates :dimension,          :presence  => true
end

class ShowbackTariff < ApplicationRecord
  has_many :showback_rates, dependent: :destroy
  validates :name, presence: true
  validates :description, presence: true
end

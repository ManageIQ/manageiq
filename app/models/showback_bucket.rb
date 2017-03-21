class ShowbackBucket < ApplicationRecord
  belongs_to :resource, polymorphic: true
  has_many :showback_charges
  has_many :showback_events, through: :showback_charges
  validates :name, presence: true
  validates :description, presence: true
  validates :resource, presence: true
end

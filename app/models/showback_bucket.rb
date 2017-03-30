class ShowbackBucket < ApplicationRecord
  belongs_to :resource, :polymorphic => true
  has_many :showback_charges, :dependent => :destroy, :inverse_of => :showback_bucket
  has_many :showback_events, :through => :showback_charges, :inverse_of => :showback_buckets
  validates :name, :presence => true
  validates :description, :presence => true
  validates :resource, :presence => true
end

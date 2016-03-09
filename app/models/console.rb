class Console < ApplicationRecord
  belongs_to :vm
  belongs_to :user

  validates_uniqueness_of :url_secret
end

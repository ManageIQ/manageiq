class Console < ApplicationRecord
  belongs_to :vm
  belongs_to :user

  validates :url_secret, :uniqueness => true
end

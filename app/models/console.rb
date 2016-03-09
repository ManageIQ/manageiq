class Console < ApplicationRecord
  belongs_to :vm
  belongs_to :user
end

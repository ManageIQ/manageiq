class NotificationRecipient < ApplicationRecord
  belongs_to :notification
  belongs_to :user
  default_value_for :seen, false

  scope :unseen, -> { where(:seen => false) }
end

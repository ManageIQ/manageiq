class NotificationRecipient < ApplicationRecord
  belongs_to :notification
  belongs_to :user
  default_value_for :seen, false
  virtual_column :details, :type => :string

  scope :unseen, -> { where(:seen => false) }

  def details
    notification.to_h.merge(:seen => seen)
  end
end

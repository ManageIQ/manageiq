class NotificationRecipient < ApplicationRecord
  belongs_to :notification
  belongs_to :user
  virtual_column :details, :type => :string

  scope :unseen, -> { where(:seen => false) }

  def details
    notification.to_h.merge(:seen => seen)
  end
end

class Notification < ApplicationRecord
  belongs_to :user

  after_commit :push_async, :on => :create

  validates :level, :inclusion => %w(success info warning error), :presence => true
  validates :message, :presence => true

  scope :unread, -> { where(:seen => false) }

  default_value_for :seen, false

  private

  def push_async
    ActionCable.server.broadcast("notifications_#{user_id}", :id => id, :level => level, :message => message)
  end
end

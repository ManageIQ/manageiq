class Notification < ApplicationRecord
  belongs_to :notification_type
  belongs_to :initiator, :class_name => User, :foreign_key => 'user_id'
  belongs_to :subject, :polymorphic => true
  belongs_to :cause, :polymorphic => true
  has_many :notification_recipients, :dependent => :delete_all
  has_many :recipients, :class_name => User, :through => :notification_recipients, :source => :user

  accepts_nested_attributes_for :notification_recipients
  before_create :set_notification_recipients

  def type=(typ)
    self.notification_type = NotificationType.find_by_name!(typ)
  end

  def to_h
    {
      :level      => notification_type.level,
      :created_at => created_at,
      :text       => notification_type.message,
      :bindings   => text_bindings
    }
  end

  private

  def set_notification_recipients
    subscribers = notification_type.subscriber_ids(subject, initiator)
    self.notification_recipients_attributes = subscribers.collect { |id| {:user_id => id } }
  end

  def text_bindings
    [:initiator, :subject, :cause].each_with_object({}) do |key, result|
      value = public_send(key)
      result[key] = {
        :link => {
          :id    => value.id,
          :model => value.class.name,
        },
        :text => value.name
      } if value
    end
  end
end

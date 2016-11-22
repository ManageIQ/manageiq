class Notification < ApplicationRecord
  belongs_to :notification_type
  belongs_to :initiator, :class_name => User, :foreign_key => 'user_id'
  belongs_to :subject, :polymorphic => true
  belongs_to :cause, :polymorphic => true
  has_many :notification_recipients, :dependent => :delete_all
  has_many :recipients, :class_name => User, :through => :notification_recipients, :source => :user

  accepts_nested_attributes_for :notification_recipients
  before_create :set_notification_recipients
  after_commit :emit_message, :on => :create

  serialize :options, Hash
  default_value_for(:options) { Hash.new }

  def type=(typ)
    self.notification_type = NotificationType.find_by_name!(typ)
  end

  def self.emit_for_event(event)
    return unless NotificationType.names.include?(event.event_type)
    type = NotificationType.find_by_name(event.event_type)
    Notification.create(:notification_type => type, :subject => event.target)
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

  def emit_message
    notification_recipients.pluck(:id, :user_id).each do |id, user|
      ActionCable.server.broadcast("notifications_#{user}", to_h.merge!(:id => id))
    end
  end

  def set_notification_recipients
    subscribers = notification_type.subscriber_ids(subject, initiator)
    if subject
      subscribers.reject! do |subscriber_id|
        Rbac.filtered_object(subject, :user => User.find(subscriber_id)).blank?
      end
    end
    self.notification_recipients_attributes = subscribers.collect { |id| {:user_id => id } }
  end

  def text_bindings
    [:initiator, :subject, :cause].each_with_object(text_bindings_dynamic) do |key, result|
      value = public_send(key)
      result[key] = {
        :link => {
          :id    => value.id,
          :model => value.class.name,
        },
        :text => value.try(:name) || value.try(:description)
      } if value
    end
  end

  def text_bindings_dynamic
    options.each_with_object({}) do |(key, value), result|
      result[key] = {
        :text => value
      }
    end
  end
end

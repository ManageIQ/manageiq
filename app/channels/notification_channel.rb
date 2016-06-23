class NotificationChannel < ApplicationCable::Channel
  def subscribed
    stream_from "notifications_#{current_user.id}" if current_user
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def mark(data)
    current_user.notifications.find(data['id'].to_i).update_attribute(:seen, true)
  end
end

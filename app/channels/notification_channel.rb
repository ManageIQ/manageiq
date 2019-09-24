class NotificationChannel < ApplicationCable::Channel
  def subscribed
    stream_from("notifications_#{current_user.id}") if current_user
  end

  def unsubscribed
    # TODO: Any cleanup needed when channel is unsubscribed
  end
end

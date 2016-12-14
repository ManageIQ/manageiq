class NotificationChannel < ApplicationCable::Channel
  def subscribed
    if current_user
      stream_from("notifications_#{current_user.id}")
    else
      @connection.close
    end
  end

  def unsubscribed
    # TODO: Any cleanup needed when channel is unsubscribed
  end
end

module NotificationMixin
  extend ActiveSupport::Concern

  def notify_task_start(message, user_id, subject = self)
    notify_task_emit(:generic_task_start, message, user_id, subject)
  end

  def notify_task_finish(message, user_id, subject = self)
    notify_task_emit(:generic_task_finish, message, user_id, subject)
  end

  def notify_task_fail(message, user_id, subject = self)
    notify_task_emit(:generic_task_fail, message, user_id, subject)
  end

  def notify_task_update(message, user_id, subject = self)
    notify_task_emit(:generic_task_update, message, user_id, subject)
  end

  private

  def notify_task_emit(type, message, user_id, subject)
    Notification.create(:type => type, :subject => subject, :user_id => user_id, :options => {:message => message})
  end
end

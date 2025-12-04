module MiqRetireTask::StateMachine
  extend ActiveSupport::Concern

  def run_retire
    signal :start_retirement
  end

  def start_retirement
    if source.retired?
      return fail!("#{self.class.model_being_retired} already retired")
    elsif source.retiring?
      return fail!("#{self.class.model_being_retired} already in the process of being retired")
    end

    create_retiring_notification!
    source.start_retirement
    signal :remove_from_provider
  end

  def remove_from_provider
    signal :check_removed_from_provider
  end

  def check_removed_from_provider
    signal :finish_retirement
  end

  def finish_retirement
    source.finish_retirement
    create_retired_notification!
    signal :delete_from_vmdb
  end

  def delete_from_vmdb
    if options[:delete_from_vmdb]
      _log.info("Removing #{self.class.model_being_retired} from VMDB")
      source.destroy
    end

    signal :finish
  end

  def finish
    mark_execution_servers
    update_and_notify_parent(:state => 'finished')
  end

  def fail!(message)
    update_and_notify_parent(:state => "finished", :status => "Error", :message => message)
    signal :finish
  end

  def create_retiring_notification!
    Notification.create!(:type => retiring_notification_type, :subject => source)
  end

  def create_retired_notification!
    Notification.create!(:type => retired_notification_type, :subject => source)
  end

  def retiring_notification_type
    "#{self.class.model_being_retired.name.underscore}_retiring".to_sym
  end

  def retired_notification_type
    "#{self.class.model_being_retired.name.underscore}_retired".to_sym
  end
end

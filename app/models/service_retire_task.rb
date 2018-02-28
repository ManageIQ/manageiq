class ServiceRetireTask < MiqRetireTask
  def self.base_model
    ServiceRetireTask
  end

  def self.model_being_retired
    Service
  end

  def update_and_notify_parent(*args)
    prev_state = state
    super
    task_finished if state == "finished" && prev_state != "finished"
  end

  def task_finished
  end
end

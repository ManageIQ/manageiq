class MiqReconfigureTask < MiqRequestTask

  def self.base_model
    MiqReconfigureTask
  end

  def self.display_name(number = 1)
    n_('Reconfigure Task', 'Reconfigure Tasks', number)
  end

  def statemachine_task_status
    if state == "finished"
      status.to_s.downcase == "error" ? "error" : "ok"
    else
      "retry"
    end
  end

  def completed_state
    "finished"
  end
end

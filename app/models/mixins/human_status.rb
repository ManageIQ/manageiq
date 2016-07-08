# Makes the `human_status` method available to models that respond to a
# `state` and `status` method.

module HumanStatus
  STATE_INITIALIZED = 'Initialized'.freeze
  STATE_QUEUED      = 'Queued'.freeze
  STATE_ACTIVE      = 'Active'.freeze
  STATE_FINISHED    = 'Finished'.freeze

  STATUS_OK         = 'Ok'.freeze
  STATUS_WARNING    = 'Warn'.freeze
  STATUS_ERROR      = 'Error'.freeze
  STATUS_TIMEOUT    = 'Timeout'.freeze
  STATUS_EXPIRED    = 'Expired'.freeze

  def human_status
    case state
    when STATE_INITIALIZED then "Initialized"
    when STATE_QUEUED      then "Queued"
    when STATE_ACTIVE      then "Running"
    when STATE_FINISHED
      case status
      when STATUS_OK      then "Complete"
      when STATUS_WARNING then "Finished with Warnings"
      when STATUS_ERROR   then "Error"
      when STATUS_TIMEOUT then "Timed Out"
      else raise _("Unknown status of: %{task_status}") % {:task_status => status.inspect}
      end
    else raise _("Unknown state of: %{task_status}") % {:task_status => state.inspect}
    end
  end
end

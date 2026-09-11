module ReconfigurationMixin
  extend ActiveSupport::Concern

  RECONFIGURATION_ERROR        = 'error_in_provisioning'.freeze
  RECONFIGURATION_PROVISIONED  = 'provisioned'.freeze
  RECONFIGURATION_PROVISIONING = 'provisioning'.freeze

  def start_reconfiguration
    return if reconfiguring?

    $log.info("Starting Reconfiguration for [id:<#{id}>, name:<#{name}>]")
    update(:lifecycle_state => RECONFIGURATION_PROVISIONING)
  end

  def finish_reconfiguration
    $log.info("Finishing Reconfiguration for [id:<#{id}>, name:<#{name}>]")
    update(:lifecycle_state => RECONFIGURATION_PROVISIONED)
  end

  def reconfiguration_error
    $log.info("Reconfiguration error for [id:<#{id}>, name:<#{name}>]")
    update(:lifecycle_state => RECONFIGURATION_ERROR)
  end

  def reconfiguring?
    lifecycle_state == RECONFIGURATION_PROVISIONING
  end

  def reconfigured?
    lifecycle_state == RECONFIGURATION_PROVISIONED
  end

  def error_reconfiguring?
    lifecycle_state == RECONFIGURATION_ERROR
  end
end

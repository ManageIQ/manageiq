module LifecycleMixin
  extend ActiveSupport::Concern

  STATE_ERROR_PROVISIONING = 'error_in_provisioning'.freeze
  STATE_PROVISIONED = 'provisioned'.freeze
  STATE_PROVISIONING = 'provisioning'.freeze

  def update_lifecycle_state
    case miq_request_task.state
    when "finished"
      lifecycle_state = miq_request_task.status == 'Ok' ? STATE_PROVISIONED : STATE_ERROR_PROVISIONING
      update(:lifecycle_state => lifecycle_state)
    else
      update(:lifecycle_state => STATE_PROVISIONING)
    end
  end

  def provisioned?
    lifecycle_state == STATE_PROVISIONED
  end

  def provision_failed?
    lifecycle_state == STATE_ERROR_PROVISIONING
  end
end

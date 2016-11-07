module ManageIQ::Providers::Azure::CloudManager::Deployment
  extend ActiveSupport::Concern

  def deployment_failed?(deployment)
    deployment.properties.provisioning_state.casecmp('failed') == 0
  end

  # Azure deployment does not contain failure reason. The actual reasons exist in the operations.
  # This method finds the FIRST error message from the operations. It can be used as the failure reason for the stack.
  # Note: There may be multiple failure reasons.
  def deployment_failure_reason(deployment_operations)
    deployment_operations.each do |operation|
      message = operation_status_message(operation)
      return message unless message.blank?
    end
    nil
  end

  def operation_status_message(operation)
    status_message = operation.properties.try(:status_message)
    return nil unless status_message

    status_message.try(:error).try(:message) || status_message.to_s
  end
end

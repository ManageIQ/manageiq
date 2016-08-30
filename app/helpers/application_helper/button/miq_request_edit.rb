class ApplicationHelper::Button::MiqRequestEdit < ApplicationHelper::Button::MiqRequest
  needs_record

  def skip?
    return true if super
    return true if %w(ServiceReconfigureRequest ServiceTemplateProvisionRequest).include?(@miq_request.try(:type))
    current_user.name != @record.requester_name || ["approved", "denied"].include?(@record.approval_state)
  end
  delegate :current_user, :to => :@view_context
end

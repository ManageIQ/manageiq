class ApplicationHelper::Button::MiqRequestEdit < ApplicationHelper::Button::MiqRequest
  needs :@miq_request, :@showtype, :@record

  def visible?
    return false unless super
    return false if %w(ServiceReconfigureRequest ServiceTemplateProvisionRequest).include?(@miq_request.try(:type))
    return false if current_user.name != @record.requester_name || %w(approved denied).include?(@record.approval_state)
    true
  end

  delegate :current_user, :to => :@view_context
end

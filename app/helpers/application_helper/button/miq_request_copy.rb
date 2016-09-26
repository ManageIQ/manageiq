class ApplicationHelper::Button::MiqRequestCopy < ApplicationHelper::Button::MiqRequest
  needs :@showtype, :@record

  def visible?
    return false unless super
    resource_types_for_miq_request_copy = %w(MiqProvisionRequest
                                             MiqHostProvisionRequest
                                             MiqProvisionConfiguredSystemRequest)
    return false if !resource_types_for_miq_request_copy.include?(@record.resource_type) ||
                    ((current_user.name != @record.requester_name ||
                    !@record.request_pending_approval?) &&
                    @showtype == "miq_provisions")
    true
  end
  delegate :current_user, :to => :@view_context
end
